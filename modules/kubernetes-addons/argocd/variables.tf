variable "helm_config" {
  description = "ArgoCD Helm Chart Config values"
  type        = any
  default     = {}
}

variable "applications" {
  description = "ArgoCD Application config used to bootstrap a cluster."
  type        = any
  default     = {}
}

variable "admin_password_secret_name" {
  description = "Name for a secret stored in AWS Secrets Manager that contains the admin password for ArgoCD."
  type        = string
  default     = ""
}

variable "addon_config" {
  description = "Configuration for managing add-ons via ArgoCD"
  type        = any
  default     = {}
}

variable "addon_context" {
  description = "Input configuration for the addon"
  type = object({
    aws_caller_identity_account_id = string
    aws_caller_identity_arn        = string
    aws_eks_cluster_endpoint       = string
    aws_partition_id               = string
    aws_region_name                = string
    eks_cluster_id                 = string
    eks_oidc_issuer_url            = string
    eks_oidc_provider_arn          = string
    tags                           = map(string)
  })
}

variable "use_kubernetes_provider" {
  description = "Use kubernetes provider"
  type        = bool
  default     = true
}

variable "use_kubectl_provider" {
  description = "Use kubectl provider"
  type        = bool
  default     = false
}
