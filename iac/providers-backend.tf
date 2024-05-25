
provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      Owner     = "company-example"
      Terraform = "true"
    }
  }
}

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "company-example-opentofu-state"
    region         = "eu-west-1"
    dynamodb_table = "iac-lock"
    key            = "company-example/terraform.tfstate"
  }
}
