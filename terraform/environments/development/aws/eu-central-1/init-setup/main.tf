module "init" {
  source       = "../../../../../modules/init-setup"
  region       = "eu-central-1"
  cluster_name = "eks-karpenter-poc"
  vpc_cidr     = "10.1.0.0/16"
  az_count     = 3
}

output "vpc_id" { value = module.init.vpc_id }
output "private_subnets" { value = module.init.private_subnets }
output "public_subnets" { value = module.init.public_subnets }
output "node_security_group_id" { value = module.init.node_security_group_id }
