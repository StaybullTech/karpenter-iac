
provider "aws" {
  region = "${AWS_REGION}"
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
    region         = "${AWS_REGION}"
    dynamodb_table = "iac-lock"
    key            = "company-example/terraform.tfstate"
  }
}
