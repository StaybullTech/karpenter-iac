locals {
  aws_account_id = "${AWS_ACCOUNT_ID}"
}

module "company-example-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "company-example-vpc"
  azs  = ["${AWS_REGION}a", "${AWS_REGION}b", "${AWS_REGION}c"]

  cidr             = "10.4.0.0/16"
  private_subnets  = ["10.4.0.0/22", "10.4.4.0/22", "10.4.8.0/22"]
  public_subnets   = ["10.4.128.0/24", "10.4.129.0/24", "10.4.130.0/24"]
  database_subnets = ["10.4.144.0/24", "10.4.145.0/24", "10.4.146.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false

  map_public_ip_on_launch = true

  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  private_subnet_tags = {
    "karpenter.sh/discovery" = "company-example-karpenter-subnet"
  }

  # AWS resource tags to add to all created resources
  tags = {
    environment = "dev"
    name        = "company-example"
  }

}
