variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "force_destroy" {
  type    = bool
  default = false
}
