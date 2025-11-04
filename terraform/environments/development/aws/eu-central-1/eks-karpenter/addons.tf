# addons.tf
locals {
  eks_addon_conflict = "OVERWRITE"
}

# Ask AWS for the latest addon versions that match your Kubernetes version
# (var.eks_version is already in your module call)
data "aws_eks_addon_version" "vpc_cni" {
  addon_name          = "vpc-cni"
  kubernetes_version  = var.eks_version
  most_recent         = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name          = "kube-proxy"
  kubernetes_version  = var.eks_version
  most_recent         = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name          = "coredns"
  kubernetes_version  = var.eks_version
  most_recent         = true
}

data "aws_eks_addon_version" "pod_identity_agent" {
  addon_name          = "eks-pod-identity-agent"
  kubernetes_version  = var.eks_version
  most_recent         = true
}

# Create core add-ons using the resolved versions
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                 = module.eks_karpenter.cluster_name
  addon_name                   = "vpc-cni"
  addon_version                = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create  = local.eks_addon_conflict
  resolve_conflicts_on_update  = local.eks_addon_conflict
  #depends_on = [aws_eks_node_group.system]
  #depends_on                  = [module.eks_karpenter]
  depends_on = [module.eks_karpenter]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                 = module.eks_karpenter.cluster_name
  addon_name                   = "kube-proxy"
  addon_version                = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create  = local.eks_addon_conflict
  resolve_conflicts_on_update  = local.eks_addon_conflict
  #depends_on = [aws_eks_node_group.system]
  depends_on = [module.eks_karpenter]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                 = module.eks_karpenter.cluster_name
  addon_name                   = "coredns"
  addon_version                = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create  = local.eks_addon_conflict
  resolve_conflicts_on_update  = local.eks_addon_conflict
  #depends_on = [aws_eks_node_group.system]
  depends_on = [module.eks_karpenter]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                 = module.eks_karpenter.cluster_name
  addon_name                   = "eks-pod-identity-agent"
  addon_version                = data.aws_eks_addon_version.pod_identity_agent.version
  resolve_conflicts_on_create  = local.eks_addon_conflict
  resolve_conflicts_on_update  = local.eks_addon_conflict
  #depends_on = [aws_eks_node_group.system]
  depends_on = [module.eks_karpenter]
}
