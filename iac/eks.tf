locals {
  vpc_id             = module.company-example-vpc.vpc_id
  private_subnet_ids = module.company-example-vpc.private_subnets
  cluster_version    = "1.29"
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

# -------------------------------------------------------------------------------------------------
# EKS cluster
# -------------------------------------------------------------------------------------------------
module "company-example-eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "20.11.0"
  create                          = true
  cluster_name                    = "company-example"
  cluster_version                 = local.cluster_version
  vpc_id                          = local.vpc_id
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Cluster authentication/authorization
  # To add the current caller identity as an administrator
  # Cluster access entry
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries = {
    Admins = {
      kubernetes_groups = []
      principal_arn     = module.iam_github_oidc_role.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = []
          }
        }
      }
    }
  }

  # Cluster encryption related settings
  create_kms_key                   = false
  attach_cluster_encryption_policy = false
  cluster_encryption_config        = {}

  subnet_ids = [
    "${local.private_subnet_ids[0]}",
    "${local.private_subnet_ids[1]}",
    "${local.private_subnet_ids[2]}",
  ]

  # manage addons and their version with terraform. The OVERWRITE option will OVERWRITE any changes made
  # with kubectl.
  cluster_addons = {
    coredns = {
      resolve_conflicts_on_update = "OVERWRITE"
      addon_version               = "v1.11.1-eksbuild.4"
    }
    kube-proxy = {
      resolve_conflicts_on_update = "OVERWRITE"
      addon_version               = "v1.29.0-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      resolve_conflicts_on_update = "OVERWRITE"
      addon_version               = "v1.30.0-eksbuild.1"
      service_account_role_arn    = module.ebs_csi_irsa.iam_role_arn
      configuration_values = jsonencode({
        sidecars = {
          snapshotter = {
            forceEnable = false
          }
        }
      })
    }
    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_update = "OVERWRITE"
      addon_version               = "v1.16.3-eksbuild.2"
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  eks_managed_node_group_defaults = {
    disk_size = 50
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
    instance_types = [
      "t3.small",
      "t3a.small",
      "t3a.medium",
      "t3.medium"
    ]
  }

  eks_managed_node_groups = {
    # Karpenter managed nodegroup
    karpenter = {
      ## The pre_bootstrap_user_data will configure max-pods=110. This also requires the
      ## the WARM_PREFIX_TARGET and ENABLE_PREFIX_DELEGATION variables to be configured
      ## with the vpc-cni addon.
      # This is supplied to the AWS EKS Optimized AMI
      # bootstrap script https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh
      # bootstrap_extra_args = "--kubelet-extra-args '--max-pods=110'"

      # This user data will be injected prior to the user data provided by the
      # AWS EKS Managed Node Group service (contains the actually bootstrap configuration)
      enable_bootstrap_user_data = true
      pre_bootstrap_user_data    = <<-EOT
        export USE_MAX_PODS=false
      EOT

      bootstrap_extra_args = "--kubelet-extra-args --max-pods=110"

      post_bootstrap_user_data = <<-EOT
        export POST_BOOTSTRAP_RAN=true
      EOT

      name = "karpenter"
      subnet_ids = [
        "${local.private_subnet_ids[0]}",
        "${local.private_subnet_ids[1]}",
        "${local.private_subnet_ids[2]}",
      ]
      min_size          = 1
      max_size          = 1
      desired_size      = 1
      instance_types    = ["t3a.small", "t3.small"]
      capacity_type     = "SPOT"
      ami_id            = data.aws_ami.eks_default.image_id
      ami_type          = "AL2_x86_64"
      enable_monitoring = true

      labels = {
        Environment = "dev"
        Application = "karpenter-ctrl"
      }

      update_config = {
        max_unavailable = 1
      }
    }

  }

  #add required ingress rule to cluster security group
  # so kubectl is usable from within the vpn
  cluster_security_group_additional_rules = {
    ingress_allow_vpc_to_kube_api = {
      description = "Allow vpc to access the kube API."
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [module.company-example-vpc.vpc_cidr_block]
    }
  }
  #add required ingress rule to node security group
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "enable node-node access"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      self        = true
      type        = "ingress"
    }
    # add required egress rules to node security group
    egress_everywhere_allICMP = {
      description = "add all icmp traffic "
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_vpc_all = {
      description = "all vpc traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = [module.company-example-vpc.vpc_cidr_block]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = "company-example-karpenter-sg"
  }

  tags = {
    Environment = "dev"
    Project     = "Karpenter"
  }
}

# -------------------------------------------------------------------------------------------------
# EBS-CSI driver IRSA (IAM Role for Service Account)
# -------------------------------------------------------------------------------------------------
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.1"

  role_name             = "ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    main = {
      provider_arn = module.company-example-eks.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:aws-node",
        "kube-system:ebs-csi-controller-sa",
        "kube-system:ebs-csi-node-sa"
      ]
    }
  }

  tags = {
    Name        = "ebs-csi-irsa"
    Environment = "dev"
  }
}

# -------------------------------------------------------------------------------------------------
# Prepare cluster for Karpenter
# -------------------------------------------------------------------------------------------------
# In the following example, the Karpenter module will create:
# An IAM role for use with Pod Identity and a scoped IAM policy for the Karpenter controller
# SQS queue and EventBridge event rules for Karpenter to utilize for spot termination handling, capacity re-balancing, etc.
# In this scenario, Karpenter will re-use an existing Node IAM role from the EKS managed nodegroup which already has the necessary access entry permissions:
#
module "karpenter" {
  source                 = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                = "20.11.0"
  enable_irsa            = true
  irsa_oidc_provider_arn = module.company-example-eks.oidc_provider_arn

  cluster_name = module.company-example-eks.cluster_name

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "dev"
  }
}

# -------------------------------------------------------------------------------------------------
# IdP/Role for Github Actions
# -------------------------------------------------------------------------------------------------
module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "5.39.1"

  tags = {
    Environment = "dev"
  }
}

module "iam_github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.39.1"
  name    = "company-example-eks-admin"

  # This should be updated to suit your organization, repository, references/branches, etc.
  # subjects = ["terraform-aws-modules/terraform-aws-iam:*"]
  subjects = [
    "StaybullTech/karpenter-iac:*"
  ]

  policies = {
    # EKSClusterAdminPolicy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    EKSView = module.EKSView.arn
  }

  tags = {
    Environment = "dev"
  }
}

module "EKSAdmin" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "5.39.1"
  name        = "EKSAdmin"
  path        = "/"
  description = "EKS Admin Policy"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "eks:*",
			"Resource": "*"
		}
	]
}
EOF
}

module "EKSView" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "5.39.1"
  name        = "EKSView"
  path        = "/"
  description = "EKS View only Policy"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"eks:ListEksAnywhereSubscriptions",
				"eks:DescribeFargateProfile",
				"eks:ListTagsForResource",
				"eks:DescribeInsight",
				"eks:ListAccessEntries",
				"eks:ListAddons",
				"eks:DescribeEksAnywhereSubscription",
				"eks:DescribeAddon",
				"eks:ListAssociatedAccessPolicies",
				"eks:DescribeNodegroup",
				"eks:ListUpdates",
				"eks:DescribeAddonVersions",
				"eks:ListIdentityProviderConfigs",
				"eks:ListNodegroups",
				"eks:DescribeAddonConfiguration",
				"eks:DescribeAccessEntry",
				"eks:DescribePodIdentityAssociation",
				"eks:ListInsights",
				"eks:ListPodIdentityAssociations",
				"eks:ListFargateProfiles",
				"eks:DescribeIdentityProviderConfig",
				"eks:DescribeUpdate",
				"eks:AccessKubernetesApi",
				"eks:DescribeCluster",
				"eks:ListClusters",
				"eks:ListAccessPolicies"
			],
			"Resource": "*"
		}
	]
}
EOF
}
