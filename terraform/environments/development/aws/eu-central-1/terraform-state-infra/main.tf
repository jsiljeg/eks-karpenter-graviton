provider "aws" { region = "eu-central-1" }

module "state" {
  source      = "../../../../../modules/terraform-state-infra"
  project     = "of-practice"
  environment = "development"
  region      = "eu-central-1"
  # force_destroy = true
}

output "state_bucket" { value = module.state.state_bucket }
output "state_lock_table" { value = module.state.state_lock_table }
