terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = {
      source = "hashicorp/aws",
      version = ">= 5.62.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  backend "s3" {
    bucket         = "of-practice-development-eu-central-1-tfstate"
    key            = "environments/development/aws/eu-central-1/eks-karpenter/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "of-practice-development-tf-lock"
    encrypt        = true
  }
}