terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 5.40.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.12.1" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.29.0" }
    kubectl    = { source = "gavinbunney/kubectl", version = ">= 1.14.0" }
  }
}
