locals {
  name = "grafana"

  service_account_name = try(var.helm_config.service_account_name, local.name)

  # https://github.com/grafana/helm-charts/blob/main/charts/grafana/Chart.yaml
  default_helm_config = {
    name        = local.name
    chart       = local.name
    repository  = "https://grafana.github.io/helm-charts"
    version     = "6.43.1"
    namespace   = local.name
    values      = local.default_helm_values
    description = "Grafana Helm Chart deployment configuration"
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    operating_system = "linux"
    region           = var.addon_context.aws_region_name
  })]

  set_values = [
    {
      name  = "serviceAccount.name"
      value = local.service_account_name
    },
    {
      name  = "serviceAccount.create"
      value = false
    }
  ]

  irsa_config = {
    kubernetes_namespace              = local.helm_config["namespace"]
    kubernetes_service_account        = local.service_account_name
    create_kubernetes_namespace       = try(local.helm_config["create_namespace"], true)
    create_kubernetes_service_account = true
    irsa_iam_policies                 = concat([aws_iam_policy.grafana.arn], var.irsa_policies)
  }

  argocd_gitops_config = {
    enable             = true
    serviceAccountName = local.name
  }
}
