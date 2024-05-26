# EKS cluster ready for karpenter
This will deploy all required AWS resources required by karpenter. You will need configure a few env vars/secrets in the Gitlab Actions that will be used here.
- AWS_ACCOUNT_ID
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION


We create an IAM role named `company-example-eks-admin` that will be used as the admin role by any users to connect to the cluster but also by gh actions. (TEST)
- note that we have created a wireguard vpn to connect to our vpc
