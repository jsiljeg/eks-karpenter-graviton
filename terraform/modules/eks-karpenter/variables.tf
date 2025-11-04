variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_security_group_id" {
  type = string
}

variable "system_mng_instance_type" {
  type    = string
  default = "t3.small"
}

variable "system_mng_desired_size" {
  type    = number
  default = 2
}

variable "system_mng_min_size" {
  type    = number
  default = 2
}

variable "eks_version" {
  type = string
  default = "1.34"
}