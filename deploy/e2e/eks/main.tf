provider "aws" {
  region = "us-west-2"
}

module "eks_cluster_with_import_vpc" {
  source = "../../../examples/eks-cluster-with-import-vpc/eks"

  tenant      = var.tenant
  environment = var.environment
  zone        = var.zone

  # VPC S3 TF State
  tf_state_vpc_s3_bucket = var.tf_state_vpc_s3_bucket
  tf_state_vpc_s3_key    = var.tf_state_vpc_s3_key
}
