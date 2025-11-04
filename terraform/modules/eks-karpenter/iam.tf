resource "aws_iam_role_policy_attachment" "node_eks" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Creates the required EC2 Spot service-linked role once per account
resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}


# IAM for Karpenter

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume.json
}


resource "aws_iam_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:Describe*",
          "ec2:DeleteLaunchTemplate",
          "pricing:GetProducts",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "iam:PassRole",
          # NEW bits ↓
          "iam:CreateServiceLinkedRole",
          "iam:ListInstanceProfiles"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_iam_role" "karpenter_node" {
  name               = "${var.cluster_name}-karpenter-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role" "events_role" {
  name               = "${var.cluster_name}-karpenter-events"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "events_to_sqs" {
  name   = "${var.cluster_name}-events-to-sqs"
  role   = aws_iam_role.events_role.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"], Resource = aws_sqs_queue.karpenter_interruptions.arn }] })
}

###########

data "aws_iam_policy_document" "karpenter_controller_extra" {
  statement {
    sid     = "AllowPricing"
    effect  = "Allow"
    actions = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid     = "AllowSQSInterruption"
    effect  = "Allow"
    actions = [
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.karpenter_interruptions.arn]
  }

  # If not already present, you also need broad Describe* for EC2 + SSM param read:
  statement {
    sid     = "DescribeEC2AndSSM"
    effect  = "Allow"
    actions = [
      "ec2:Describe*",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = ["*"]
  }

  # And the pass role to the node instance profile:
  statement {
    sid     = "PassNodeRole"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node.arn]
  }

  # EKS DescribeCluster is also required:
  statement {
    sid     = "DescribeCluster"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "karpenter_controller_extra" {
  name   = "${var.cluster_name}-karpenter-controller-extra"
  policy = data.aws_iam_policy_document.karpenter_controller_extra.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_extra_attach" {
  role       = aws_iam_role.karpenter_controller.name   # your controller role
  policy_arn = aws_iam_policy.karpenter_controller_extra.arn
}
