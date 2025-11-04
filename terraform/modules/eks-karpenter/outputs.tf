output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

# Karpenter wiring
output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}
output "karpenter_node_instance_profile_name" {
  value = aws_iam_instance_profile.karpenter_node.name
}
output "karpenter_interruptions_queue_arn" {
  value = aws_sqs_queue.karpenter_interruptions.arn
}

output "karpenter_interruptions_queue_name" {
  value = aws_sqs_queue.karpenter_interruptions.name
}

output "cluster_security_group_id" {
  description = "Cluster primary security group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Shared node security group ID"
  value       = module.eks.node_security_group_id
}


