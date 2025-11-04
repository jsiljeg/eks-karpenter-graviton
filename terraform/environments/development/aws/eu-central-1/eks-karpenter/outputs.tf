output "cluster_name" { value = module.eks_karpenter.cluster_name }
output "region" { value = module.eks_karpenter.region }
output "cluster_endpoint" { value = module.eks_karpenter.cluster_endpoint }
output "system_ng_subnets_effective" { value = local.system_ng_subnets }
