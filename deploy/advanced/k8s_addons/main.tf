/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

terraform {
  required_version = ">= 1.0.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.7.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }
}

provider "aws" {
  region = data.aws_region.current.id
  alias  = "default"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

#---------------------------------------------------------------
# Note: Terraform_remote_state for S3 backend can be imported using the below code snippet
#---------------------------------------------------------------
/*
data "terraform_remote_state" "vpc_s3_backend" {
  backend = "s3"
  config = {
    bucket = ""     # Bucket name
    key = ""        # Key path to terraform-main.tfstate file
    region = ""     # aws region
  }

  vpc_id = data.terraform_remote_state.vpc_s3_backend.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc_s3_backend.outputs.private_subnets
  public_subnet_ids = data.terraform_remote_state.vpc_s3_backend.outputs.public_subnets

}*/

locals {
  tenant       = var.tenant
  environment  = var.environment
  zone         = var.zone
  cluster_name = join("-", [local.tenant, local.environment, local.zone, "eks"])

  kubernetes_version = "1.21"
  terraform_version  = "Terraform v1.0.1"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
}

#---------------------------------------------------------------
# Example to consume aws-eks-accelerator-for-terraform module
#---------------------------------------------------------------
module "aws-eks-accelerator-for-terraform" {
  source = "../../.."

  tenant            = local.tenant
  environment       = local.environment
  zone              = local.zone
  terraform_version = local.terraform_version

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids

  # EKS CONTROL PLANE VARIABLES
  create_eks         = true
  kubernetes_version = local.kubernetes_version

  # EKS MANAGED NODE GROUPS
  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_4 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      subnet_ids      = local.private_subnet_ids
    }
  }

  # EKS SELF-MANAGED NODE GROUPS
  self_managed_node_groups = {
    self_mg_4 = {
      node_group_name    = "self-managed-ondemand"
      instance_types     = ["m4.large"]
      launch_template_os = "amazonlinux2eks"       # amazonlinux2eks  or bottlerocket or windows
      custom_ami_id      = "ami-0dfaa019a300f219c" # Bring your own custom AMI generated by Packer/ImageBuilder/Puppet etc.
      subnet_ids         = local.private_subnet_ids
    }
  }
  # Fargate profiles
  fargate_profiles = {
    default = {
      fargate_profile_name = "default"
      fargate_profile_namespaces = [
        {
          namespace = "default"
          k8s_labels = {
            Environment = "preprod"
            Zone        = "dev"
            env         = "fargate"
          }
      }]
      subnet_ids = local.private_subnet_ids
      additional_tags = {
        ExtraTag = "Fargate"
      }
    },
  }

  # AWS Managed Services
  aws_managed_prometheus_enable = true

  enable_emr_on_eks = true
  emr_on_eks_teams = {
    data_team_a = {
      emr_on_eks_namespace     = "emr-data-team-a"
      emr_on_eks_iam_role_name = "emr-eks-data-team-a"
    }

    data_team_b = {
      emr_on_eks_namespace     = "emr-data-team-b"
      emr_on_eks_iam_role_name = "emr-eks-data-team-b"
    }
  }

}

module "kubernetes-addons" {
  source = "../../../kubernetes-addons"

  eks_cluster_id               = module.aws-eks-accelerator-for-terraform.eks_cluster_id
  eks_cluster_oidc_url         = module.aws-eks-accelerator-for-terraform.eks_cluster_oidc_url
  eks_oidc_provider_arn        = module.aws-eks-accelerator-for-terraform.eks_cluster_oidc_provider_arn
  eks_worker_security_group_id = module.aws-eks-accelerator-for-terraform.worker_security_group_id
  auto_scaling_group_names     = module.aws-eks-accelerator-for-terraform.self_managed_node_group_autoscaling_groups

  # EKS Addons
  enable_eks_addon_vpc_cni = true # default is false
  #Optional
  eks_addon_vpc_cni_config = {
    addon_name               = "vpc-cni"
    addon_version            = "v1.10.1-eksbuild.1"
    service_account          = "aws-node"
    resolve_conflicts        = "OVERWRITE"
    namespace                = "kube-system"
    additional_iam_policies  = []
    service_account_role_arn = ""
    tags                     = {}
  }

  enable_eks_addon_coredns = true # default is false
  #Optional
  eks_addon_coredns_config = {
    addon_name               = "coredns"
    addon_version            = "v1.8.4-eksbuild.1"
    service_account          = "coredns"
    resolve_conflicts        = "OVERWRITE"
    namespace                = "kube-system"
    service_account_role_arn = ""
    additional_iam_policies  = []
    tags                     = {}
  }

  enable_eks_addon_kube_proxy = true # default is false
  #Optional
  eks_addon_kube_proxy_config = {
    addon_name               = "kube-proxy"
    addon_version            = "v1.21.2-eksbuild.2"
    service_account          = "kube-proxy"
    resolve_conflicts        = "OVERWRITE"
    namespace                = "kube-system"
    additional_iam_policies  = []
    service_account_role_arn = ""
    tags                     = {}
  }

  enable_eks_addon_aws_ebs_csi_driver = true # default is false
  #Optional
  eks_addon_aws_ebs_csi_driver_config = {
    addon_name               = "aws-ebs-csi-driver"
    addon_version            = "v1.4.0-eksbuild.preview"
    service_account          = "ebs-csi-controller-sa"
    resolve_conflicts        = "OVERWRITE"
    namespace                = "kube-system"
    additional_iam_policies  = []
    service_account_role_arn = ""
    tags                     = {}
  }
  #---------------------------------------
  # AWS LOAD BALANCER INGRESS CONTROLLER HELM ADDON
  #---------------------------------------
  aws_lb_ingress_controller_enable = true
  # Optional
  aws_lb_ingress_controller_helm_chart = {
    name                       = "aws-load-balancer-controller"
    chart                      = "aws-load-balancer-controller"
    repository                 = "https://aws.github.io/eks-charts"
    version                    = "1.3.1"
    namespace                  = "kube-system"
  }

  #---------------------------------------
  # AWS NODE TERMINATION HANDLER HELM ADDON
  #---------------------------------------
  aws_node_termination_handler_enable = true
  # Optional
  aws_node_termination_handler_helm_chart = {
    name                       = "aws-node-termination-handler"
    chart                      = "aws-node-termination-handler"
    repository                 = "https://aws.github.io/eks-charts"
    version                    = "0.16.0"
    timeout                    = "1200"
  }
  #---------------------------------------
  # TRAEFIK INGRESS CONTROLLER HELM ADDON
  #---------------------------------------
  traefik_ingress_controller_enable = true

  # Optional Map value
  traefik_helm_chart = {
    name       = "traefik"                         # (Required) Release name.
    repository = "https://helm.traefik.io/traefik" # (Optional) Repository URL where to locate the requested chart.
    chart      = "traefik"                         # (Required) Chart name to be installed.
    version    = "10.0.0"                          # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "kube-system"                     # (Optional) The namespace to install the release into. Defaults to default
    timeout    = "1200"                            # (Optional)
    lint       = "true"                            # (Optional)
    # (Optional) Example to show how to override values using SET
    set = [{
      name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }]
    # (Optional) Example to show how to pass metrics-server-values.yaml
    values = [templatefile("${path.module}/helm_values/traefik-values.yaml", {
      operating_system = "linux"
    })]
  }

  #---------------------------------------
  # METRICS SERVER HELM ADDON
  #---------------------------------------
  metrics_server_enable = true

  # Optional Map value
  metrics_server_helm_chart = {
    name       = "metrics-server"                                    # (Required) Release name.
    repository = "https://kubernetes-sigs.github.io/metrics-server/" # (Optional) Repository URL where to locate the requested chart.
    chart      = "metrics-server"                                    # (Required) Chart name to be installed.
    version    = "3.5.0"                                             # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "kube-system"                                       # (Optional) The namespace to install the release into. Defaults to default
    timeout    = "1200"                                              # (Optional)
    lint       = "true"                                              # (Optional)

    # (Optional) Example to show how to pass metrics-server-values.yaml
    values = [templatefile("${path.module}/helm_values/metrics-server-values.yaml", {
      operating_system = "linux"
    })]
  }

  #---------------------------------------
  # CLUSTER AUTOSCALER HELM ADDON
  #---------------------------------------
  cluster_autoscaler_enable = true

  # Optional Map value
  cluster_autoscaler_helm_chart = {
    name       = "cluster-autoscaler"                      # (Required) Release name.
    repository = "https://kubernetes.github.io/autoscaler" # (Optional) Repository URL where to locate the requested chart.
    chart      = "cluster-autoscaler"                      # (Required) Chart name to be installed.
    version    = "9.10.7"                                  # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "kube-system"                             # (Optional) The namespace to install the release into. Defaults to default
    timeout    = "1200"                                    # (Optional)
    lint       = "true"                                    # (Optional)

    # (Optional) Example to show how to pass metrics-server-values.yaml
    values = [templatefile("${path.module}/helm_values/cluster-autoscaler-vaues.yaml", {
      operating_system = "linux"
    })]
  }
  #---------------------------------------
  # COMMUNITY PROMETHEUS ENABLE
  #---------------------------------------
  prometheus_enable = true

  # Optional Map value
  prometheus_helm_chart = {
    name       = "prometheus"                                         # (Required) Release name.
    repository = "https://prometheus-community.github.io/helm-charts" # (Optional) Repository URL where to locate the requested chart.
    chart      = "prometheus"                                         # (Required) Chart name to be installed.
    version    = "14.4.0"                                             # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "prometheus"                                         # (Optional) The namespace to install the release into. Defaults to default
    values = [templatefile("${path.module}/helm_values/prometheus-values.yaml", {
      operating_system = "linux"
    })]

  }


  #---------------------------------------
  # ENABLE NGINX
  #---------------------------------------
  ingress_nginx_controller_enable = true

  # Optional nginx_helm_chart
  nginx_helm_chart = {
    name       = "ingress-nginx"
    chart      = "ingress-nginx"
    repository = "https://kubernetes.github.io/ingress-nginx"
    version    = "3.33.0"
    namespace  = "kube-system"
    values     = [templatefile("${path.module}/helm_values/nginx_default_values.yaml", {})]
  }

  #---------------------------------------
  # ENABLE AGONES
  #---------------------------------------
  # NOTE: Agones requires a Node group in Public Subnets and enable Public IP
  agones_enable = true
  # Optional  agones_helm_chart
  agones_helm_chart = {
    name               = "agones"
    chart              = "agones"
    repository         = "https://agones.dev/chart/stable"
    version            = "1.15.0"
    namespace          = "kube-system"
    gameserver_minport = 7000 # required for sec group changes to worker nodes
    gameserver_maxport = 8000 # required for sec group changes to worker nodes
    values = [templatefile("${path.module}/helm_values/agones-values.yaml", {
      expose_udp            = true
      gameserver_namespaces = "{${join(",", ["default", "xbox-gameservers", "xbox-gameservers"])}}"
      gameserver_minport    = 7000
      gameserver_maxport    = 8000
    })]
  }

  #---------------------------------------
  # ENABLE AWS DISTRO OPEN TELEMETRY
  #---------------------------------------
  aws_open_telemetry_enable = true
  # Optional
  aws_open_telemetry_addon = {
    aws_open_telemetry_namespace                        = "aws-otel-eks"
    aws_open_telemetry_emitter_otel_resource_attributes = "service.namespace=AWSObservability,service.name=ADOTEmitService"
    aws_open_telemetry_emitter_name                     = "trace-emitter"
    aws_open_telemetry_emitter_image                    = "public.ecr.aws/g9c4k4i4/trace-emitter:1"
    aws_open_telemetry_collector_image                  = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
    aws_open_telemetry_aws_region                       = "eu-west-1"
    aws_open_telemetry_emitter_oltp_endpoint            = "localhost:55680"
  }

  #---------------------------------------
  # AWS-FOR-FLUENTBIT HELM ADDON
  #---------------------------------------
  aws_for_fluentbit_enable = true
  # Optional
  aws_for_fluentbit_helm_chart = {
    name                                      = "aws-for-fluent-bit"
    chart                                     = "aws-for-fluent-bit"
    repository                                = "https://aws.github.io/eks-charts"
    version                                   = "0.1.0"
    namespace                                 = "logging"
    aws_for_fluent_bit_cw_log_group           = "/${local.cluster_name}/worker-fluentbit-logs" # Optional
    aws_for_fluentbit_cwlog_retention_in_days = 90
    create_namespace                          = true
    values = [templatefile("${path.module}/helm_values/aws-for-fluentbit-values.yaml", {
      region                          = data.aws_region.current.name,
      aws_for_fluent_bit_cw_log_group = "/${local.cluster_name}/worker-fluentbit-logs"
    })]
    set = [
      {
        name  = "nodeSelector.kubernetes\\.io/os"
        value = "linux"
      }
    ]
  }

  #---------------------------------------
  # ENABLE SPARK on K8S OPERATOR
  #---------------------------------------
  spark_on_k8s_operator_enable = true

  # Optional
  spark_on_k8s_operator_helm_chart = {
    name             = "spark-operator"
    chart            = "spark-operator"
    repository       = "https://googlecloudplatform.github.io/spark-on-k8s-operator"
    version          = "1.1.6"
    namespace        = "spark-k8s-operator"
    timeout          = "1200"
    create_namespace = true
    values           = [templatefile("${path.module}/helm_values/spark-k8s-operator-values.yaml", {})]

  }

  #---------------------------------------
  # FARGATE FLUENTBIT
  #---------------------------------------
  fargate_fluentbit_enable = true

  # Optional
  fargate_fluentbit_config = {
    output_conf  = <<EOF
[OUTPUT]
  Name cloudwatch_logs
  Match *
  region eu-west-1
  log_group_name /${local.cluster_name}/fargate-fluentbit-logs
  log_stream_prefix "fargate-logs-"
  auto_create_group true
    EOF
    filters_conf = <<EOF
[FILTER]
  Name parser
  Match *
  Key_Name log
  Parser regex
  Preserve_Key On
  Reserve_Data On
    EOF
    parsers_conf = <<EOF
[PARSER]
  Name regex
  Format regex
  Regex ^(?<time>[^ ]+) (?<stream>[^ ]+) (?<logtag>[^ ]+) (?<message>.+)$
  Time_Key time
  Time_Format %Y-%m-%dT%H:%M:%S.%L%z
  Time_Keep On
  Decode_Field_As json message
    EOF
  }

  #---------------------------------------
  # ENABLE ARGOCD
  #---------------------------------------
  argocd_enable = true

  # Optional
  argocd_helm_chart = {
    name             = "argo-cd"
    chart            = "argo-cd"
    repository       = "https://argoproj.github.io/argo-helm"
    version          = "3.26.3"
    namespace        = "argocd"
    timeout          = "1200"
    create_namespace = true
    values           = [templatefile("${path.module}/helm_values/argocd-values.yaml", {})]
  }

  #---------------------------------------
  # KEDA ENABLE
  #---------------------------------------
  keda_enable = true

  # Optional
  keda_helm_chart = {
    name       = "keda"                              # (Required) Release name.
    repository = "https://kedacore.github.io/charts" # (Optional) Repository URL where to locate the requested chart.
    chart      = "keda"                              # (Required) Chart name to be installed.
    version    = "2.4.0"                             # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "keda"                              # (Optional) The namespace to install the release into. Defaults to default
    values     = [templatefile("${path.module}/helm_values/keda-values.yaml", {})]
  }

  #---------------------------------------
  # Vertical Pod Autoscaling
  #---------------------------------------
  vpa_enable = true

  vpa_helm_chart = {
    name       = "vpa"                                 # (Required) Release name.
    repository = "https://charts.fairwinds.com/stable" # (Optional) Repository URL where to locate the requested chart.
    chart      = "vpa"                                 # (Required) Chart name to be installed.
    version    = "0.5.0"                               # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    namespace  = "vpa-ns"                              # (Optional) The namespace to install the release into. Defaults to default
    values     = [templatefile("${path.module}/helm_values/vpa-values.yaml", {})]
  }

  #---------------------------------------
  # Apache YuniKorn K8s Spark Scheduler
  #---------------------------------------
  yunikorn_enable = true

  yunikorn_helm_chart = {
    name       = "yunikorn"                                            # (Required) Release name.
    repository = "https://apache.github.io/incubator-yunikorn-release" # (Optional) Repository URL where to locate the requested chart.
    chart      = "yunikorn"                                            # (Required) Chart name to be installed.
    version    = "0.12.0"                                              # (Optional) Specify the exact chart version to install. If this is not specified, the latest version is installed.
    values     = [templatefile("${path.module}/helm_values/yunikorn-values.yaml", {})]
  }

}
