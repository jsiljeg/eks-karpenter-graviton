terraform {
  backend "s3" {
    bucket         = "of-practice-development-eu-central-1-tfstate"
    key            = "environments/development/aws/eu-central-1/init-setup/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "of-practice-development-tf-lock"
    encrypt        = true
  }
}
