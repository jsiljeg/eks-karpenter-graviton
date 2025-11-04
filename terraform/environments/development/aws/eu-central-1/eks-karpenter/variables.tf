variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "eks_version" {
  description = "EKS control plane version"
  type        = string
  default     = "1.34"
}

variable "karpenter_version" {
  description = "Karpenter chart & CRD version"
  type        = string
  default     = "1.8.1"
}

variable "capacity_type" {
  description = "Karpenter NodePool capacity type label value"
  type        = string
  default     = "spot"
}

variable "amd64_instance_types" {
  description = "Allowed instance types for amd64 NodePool"
  type        = list(string)
  default     = ["t3.micro", "t3.small", "c7i-flex.large", "m7i-flex.large"]
}

variable "arm64_instance_types" {
  description = "Allowed instance types for arm64 NodePool"
  type        = list(string)
  default     = ["t4g.micro", "t4g.small"]
}

variable "system_mng_desired_size" {
  description = "Desired size for the small system managed node group"
  type        = number
  default     = 2
}

variable "system_mng_min_size" {
  description = "Minimal size for the small system managed node group"
  type        = number
  default     = 2
}

# Put system nodes in public subnets temporarily (egress) or private (with NAT/endpoints)
variable "system_ng_in_public" {
  description = "true = use public subnets, false = use private subnets"
  type        = bool
  default     = true
}

# Allow multiple types to avoid capacity stalls
variable "system_mng_instance_types" {
  description = "Instance types for the system managed node group"
  type        = list(string)
  default     = ["t3.small", "t3.medium", "t3a.small"]
}

