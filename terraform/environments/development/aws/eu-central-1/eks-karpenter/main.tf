data "terraform_remote_state" "init" {
  backend = "s3"
  config = {
    bucket         = "of-practice-development-eu-central-1-tfstate"
    key            = "environments/development/aws/eu-central-1/init-setup/terraform.tfstate"
    region         = var.region
    dynamodb_table = "of-practice-development-tf-lock"
    encrypt        = true
  }
}


locals {
  system_ng_subnets = var.system_ng_in_public ? data.terraform_remote_state.init.outputs.public_subnets : data.terraform_remote_state.init.outputs.private_subnets
}

module "eks_karpenter" {
  source                   = "../../../../../modules/eks-karpenter"

  region                   = var.region
  cluster_name             = "eks-karpenter-poc"
  vpc_id                   = data.terraform_remote_state.init.outputs.vpc_id
  private_subnet_ids       = data.terraform_remote_state.init.outputs.private_subnets
  node_security_group_id   = data.terraform_remote_state.init.outputs.node_security_group_id

  system_mng_instance_type = "t3.small"
  system_mng_desired_size  = var.system_mng_desired_size
  system_mng_min_size      = var.system_mng_min_size
  eks_version              = var.eks_version
}

resource "time_sleep" "after_cluster_ready" {
  depends_on = [module.eks_karpenter]
  create_duration = "45s"
}
