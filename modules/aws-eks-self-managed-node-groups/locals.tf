locals {
  lt_self_managed_group_map_key = "self-managed-node-group"

  default_self_managed_ng = {
    node_group_name = "m4_on_demand"
    instance_type   = "m4.large"
    instance_types  = ["m4.large"]

    # LAUNCH TEMPLATES
    custom_ami_id            = ""          # Bring your own custom AMI generated by Packer/ImageBuilder/Puppet etc.
    capacity_type            = "on_demand" # on_demand, spot
    capacity_rebalance       = false
    spot_allocation_strategy = "capacity-optimized-prioritized"
    launch_template_os       = "amazonlinux2eks" # amazonlinux2eks/bottlerocket/windows # Used to identify the launch template
    pre_userdata             = ""
    post_userdata            = ""
    kubelet_extra_args       = ""
    bootstrap_extra_args     = ""
    enable_monitoring        = false
    public_ip                = false

    block_device_mappings = [
      {
        device_name = "/dev/xvda"
        volume_type = "gp3"
        volume_size = 50
      }
    ]

    # AUTOSCALING
    max_size                = "3"
    min_size                = "1"
    subnet_type             = "private"
    subnet_ids              = []
    additional_tags         = {}
    additional_iam_policies = []
  }

  needs_mixed_instances_policy = length(local.self_managed_node_group["instance_types"]) > 1 ? true : false

  self_managed_node_group = merge(
    local.default_self_managed_ng,
    var.self_managed_ng
  )

  enable_windows_support = local.self_managed_node_group["launch_template_os"] == "windows"

  predefined_ami_names = {
    amazonlinux2eks = "amazon-eks-node-${var.context.cluster_version}-*"
    bottlerocket    = "bottlerocket-aws-k8s-${var.context.cluster_version}-x86_64-*"
    windows         = "Windows_Server-2019-English-Core-EKS_Optimized-${var.context.cluster_version}-*"
  }

  predefined_ami_types  = keys(local.predefined_ami_names)
  default_custom_ami_id = contains(local.predefined_ami_types, local.self_managed_node_group["launch_template_os"]) ? data.aws_ami.predefined[local.self_managed_node_group["launch_template_os"]].id : ""
  custom_ami_id         = local.self_managed_node_group["custom_ami_id"] == "" ? local.default_custom_ami_id : local.self_managed_node_group["custom_ami_id"]

  policy_arn_prefix = "arn:${var.context.aws_partition_id}:iam::aws:policy"
  ec2_principal     = "ec2.${var.context.aws_partition_dns_suffix}"

  # EKS Worker Managed Policies
  eks_worker_policies = toset(concat([
    "${local.policy_arn_prefix}/AmazonEKSWorkerNodePolicy",
    "${local.policy_arn_prefix}/AmazonEKS_CNI_Policy",
    "${local.policy_arn_prefix}/AmazonEC2ContainerRegistryReadOnly",
    "${local.policy_arn_prefix}/AmazonSSMManagedInstanceCore"],
    local.self_managed_node_group["additional_iam_policies"
  ]))

  common_tags = merge(
    var.context.tags,
    local.self_managed_node_group["additional_tags"],
    {
      Name                                                      = "${local.self_managed_node_group["node_group_name"]}-${var.context.eks_cluster_id}"
      "k8s.io/cluster-autoscaler/${var.context.eks_cluster_id}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"                       = "TRUE"
      "kubernetes.io/cluster/${var.context.eks_cluster_id}"     = "owned"
  })
}
