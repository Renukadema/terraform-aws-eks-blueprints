module "helm_addon" {
  source                  = "../helm-addon"
  manage_via_gitops       = var.manage_via_gitops
  helm_config             = local.helm_config
  irsa_config             = null
  addon_context           = var.addon_context
  use_kubernetes_provider = var.use_kubernetes_provider
  use_kubectl_provider    = var.use_kubectl_provider

  depends_on = [kubernetes_namespace_v1.yunikorn]
}

resource "kubernetes_namespace_v1" "yunikorn" {
  count = try(local.helm_config["create_namespace"], true) && local.helm_config["namespace"] != "kube-system" ? 1 : 0
  metadata {
    name = local.helm_config["namespace"]
  }
}
