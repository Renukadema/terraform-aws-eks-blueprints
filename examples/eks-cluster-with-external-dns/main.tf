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

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_id
}

data "aws_acm_certificate" "issued" {
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED"]
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
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30"

  cluster_name    = local.name
  cluster_version = "1.23"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_nodes_alb_controller_port = {
      description                   = "Cluster API to Node group for ALB controller webhook"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
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
  source = "../../modules/kubernetes-addons"

  eks_cluster_id       = module.eks.cluster_id
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_oidc_provider    = module.eks.oidc_provider
  eks_cluster_version  = module.eks.cluster_version
  eks_cluster_domain   = var.eks_cluster_domain

  enable_argocd = true
  argocd_applications = {
    workloads = {
      path     = "envs/dev"
      repo_url = "https://github.com/aws-samples/eks-blueprints-workloads.git"
      values = {
        spec = {
          ingress = {
            host = var.eks_cluster_domain
          }
        }
      }
    }
  }

  enable_ingress_nginx = true
  ingress_nginx_helm_config = {
    values = [templatefile("${path.module}/nginx-values.yaml", {
      hostname     = var.eks_cluster_domain
      ssl_cert_arn = data.aws_acm_certificate.issued.arn
    })]
  }

  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true

  tags = local.tags
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
