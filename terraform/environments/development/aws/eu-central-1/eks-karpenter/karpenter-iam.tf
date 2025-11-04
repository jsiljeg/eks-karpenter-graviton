data "aws_caller_identity" "current" {}

# Access Entry for node role (lets EC2 worker nodes register)
resource "aws_eks_access_entry" "karpenter_nodes" {
  cluster_name  = module.eks_karpenter.cluster_name
  principal_arn = local.node_role_arn
  type          = "EC2_LINUX"
  depends_on    = [module.eks_karpenter]
}


locals {
  region               = var.region
  cluster_name         = module.eks_karpenter.cluster_name
  # Build cluster ARN without aws_region data source (avoid deprecation)
  cluster_arn          = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${module.eks_karpenter.cluster_name}"

  node_role_name = "${module.eks_karpenter.cluster_name}-karpenter-node"
  node_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.node_role_name}"

  controller_role_name = "${local.cluster_name}-karpenter-controller"
}

# Look up the controller role created by the EKS/Karpenter module
data "aws_iam_role" "karpenter_controller" {
  name       = local.controller_role_name
  depends_on = [module.eks_karpenter]
}

# Managed policy: DescribeCluster + read public SSM params + DescribeImages
data "aws_iam_policy_document" "karpenter_controller_managed" {
  statement {
    sid     = "AllowDescribeCluster"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }
  statement {
    sid     = "AllowReadPublicSSMParams"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.region}::parameter/aws/service/eks/*",
      "arn:aws:ssm:${var.region}::parameter/aws/service/bottlerocket/*",
    ]
  }
  statement {
    sid     = "AllowDescribeImages"
    effect  = "Allow"
    actions = ["ec2:DescribeImages"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "karpenter_controller_managed" {
  name        = "${local.cluster_name}-karpenter-controller-managed"
  description = "DescribeCluster + read public SSM params + DescribeImages"
  policy      = data.aws_iam_policy_document.karpenter_controller_managed.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_managed_attach" {
  role       = data.aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller_managed.arn
}

# Inline policy (same scopes — optional but keeps parity with your previous setup)
resource "aws_iam_role_policy" "karpenter_controller_inline" {
  name   = "${local.cluster_name}-karpenter-controller-inline"
  role   = data.aws_iam_role.karpenter_controller.name
  policy = data.aws_iam_policy_document.karpenter_controller_managed.json
}

# --- IAM role for the node group ---
resource "aws_iam_role" "system_ng" {
  name               = "${module.eks_karpenter.cluster_name}-system-ng"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "system_ng_worker" {
  role       = aws_iam_role.system_ng.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "system_ng_cni" {
  role       = aws_iam_role.system_ng.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "system_ng_ecr" {
  role       = aws_iam_role.system_ng.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

