# OpenTofu
You could use the `iac/` folder to deploy the VPC and EKS AWS resources without github actions by simply running `tofu init && tofu plan && tofu apply` in that folder.
You would only need to replace the Env vars configured in the `eks.tf` and `providers-backends.tf` files with their respective values. You would also need to configure your AWS profile (either IAM credentials of IAM role, etc).

## Variables
The following environment variables could help run Tofu without the github actions workflow.
- AWS_ACCOUNT_ID
- AWS_REGION
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

## Kubectl access
We create an IAM role named `company-example-eks-admin` that will be used as the admin role by any users to connect to the cluster but also by gh actions. Your use will need to able to assume this role if you want to deploy AWS resources without GH actions.

## Existing VPC
In the case where you already have a VPC with subnets that you could use for your EKS cluster you can simply delete the `iac/vpc.tf` file and update the `vpc_id` and `private_subnet_ids` local variables in the `eks.tf` file accordingly
