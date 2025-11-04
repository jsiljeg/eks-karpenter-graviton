module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.8.0"

  name                = var.cluster_name
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  kubernetes_version  = var.eks_version
  enable_irsa         = true
  endpoint_public_access  = true
  endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true

  addons = {}

  tags = { "karpenter.sh/discovery" = var.cluster_name }
}

# Interruption handling
resource "aws_sqs_queue" "karpenter_interruptions" {
  name                        = "${var.cluster_name}-karpenter-interruptions"
  message_retention_seconds   = 300
  visibility_timeout_seconds  = 30
}

#########

resource "aws_cloudwatch_event_rule" "karpenter_interruptions" {
  name        = "${var.cluster_name}-karpenter-interruptions"
  description = "Capture EC2 interruption events for Karpenter"
  event_pattern = jsonencode({
    "source"      : ["aws.ec2"],
    "detail-type" : [
      "EC2 Spot Instance Interruption Warning",
      "EC2 Instance Rebalance Recommendation",
      "EC2 Instance State-change Notification"
    ]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_sqs_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_interruptions.name
  target_id = "karpenter-interruption-queue"
  arn       = aws_sqs_queue.karpenter_interruptions.arn
}

resource "aws_sqs_queue_policy" "karpenter_interruptions" {
  queue_url = aws_sqs_queue.karpenter_interruptions.id
  policy    = data.aws_iam_policy_document.karpenter_sqs.json

  depends_on = [
    aws_cloudwatch_event_rule.karpenter_interruptions
  ]
}

# Stable, deterministic JSON for the queue policy
data "aws_iam_policy_document" "karpenter_sqs" {
  statement {
    sid     = "AllowEventBridge"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sqs_queue.karpenter_interruptions.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.karpenter_interruptions.arn]
    }
  }
}


