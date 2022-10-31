provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }

  application = "nginx"
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30"

  cluster_name    = local.name
  cluster_version = "1.23"

  cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_nodes_ephemeral = {
      description = "Node-to-node on ephemeral ports"
      protocol    = "tcp"
      from_port   = 1025
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description = "Allow all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "../../../modules/kubernetes-addons"

  eks_cluster_id       = module.eks.cluster_id
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_oidc_provider    = module.eks.oidc_provider
  eks_cluster_version  = module.eks.cluster_version

  # Wait on the `kube-system` profile before provisioning addons
  data_plane_wait_arn = module.eks.eks_managed_node_groups["default"].node_group_arn

  #K8s Add-ons
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true

  tags = local.tags
}

#------------------------------------------------------------------------------------
# Create a sample secret in Secret Manager
#------------------------------------------------------------------------------------

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_kms_key" "secrets" {
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "application_secret" {
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "sversion" {
  secret_id     = aws_secretsmanager_secret.application_secret.id
  secret_string = <<-EOT
  {
    "username": "adminaccount",
    "password": "${random_password.password.result}"
  }
  EOT
}

data "aws_iam_policy_document" "secrets_management_policy" {
  statement {
    sid    = ""
    effect = "Allow"
    resources = [
      aws_secretsmanager_secret_version.sversion.arn
    ]
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
  }
}

resource "aws_iam_policy" "this" {
  description = "Sample application IAM Policy for IRSA"
  name        = "${module.eks.cluster_id}-${local.application}-irsa"
  policy      = data.aws_iam_policy_document.secrets_management_policy.json
}

module "iam_role_service_account" {
  source                     = "../../../modules/irsa"
  eks_cluster_id             = module.eks.cluster_id
  eks_oidc_provider_arn      = module.eks.oidc_provider_arn
  kubernetes_namespace       = local.application
  kubernetes_service_account = "${local.application}-sa"
  irsa_iam_policies          = [aws_iam_policy.this.arn]
}

#---------------------------------------------------------------
# Kubernetes CRD to create the "SecretProviderClass" to represent the Secrets Manager Secrets
# Refer https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html#integrating_csi_driver_SecretProviderClass for syntax
#---------------------------------------------------------------
resource "kubectl_manifest" "csi_secrets_store_crd" {
  yaml_body = yamlencode({
    apiVersion = "secrets-store.csi.x-k8s.io/v1alpha1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "${local.application}-secrets"
      namespace = local.application
    }
    spec = {
      provider = "aws"
      parameters = {
        objects = <<-EOT
          - objectName : ${aws_secretsmanager_secret_version.sversion.arn}
        EOT
      }
    }
  })
  depends_on = [module.iam_role_service_account]
}

#---------------------------------------------------------------
# Sample Kubernetes Pod to mount the Secrets as CSI Volume
#---------------------------------------------------------------
resource "kubectl_manifest" "sample_nginx" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Pod"
    metadata = {
      name      = "${local.application}-secrets-pod-sample"
      namespace = local.application
    }
    spec = {
      serviceAccountName = "${local.application}-sa"
      volumes = [
        {
          name = "${local.application}-secrets-volume"
          csi = {
            driver   = "secrets-store.csi.k8s.io"
            readOnly = true
            volumeAttributes = {
              secretProviderClass : "${local.application}-secrets"
            }
          }
        }
      ]
      containers = [
        {
          name  = "${local.application}-deployment"
          image = "nginx"
          ports = [
            {
              containerPort = 80
            }
          ]
          volumeMounts = [
            {
              name      = "${local.application}-secrets-volume"
              mountPath = "/mnt/secrets-store"
              readOnly  = true
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.csi_secrets_store_crd,
    module.iam_role_service_account,
  ]
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
