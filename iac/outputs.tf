output "karpenter-controller-role-arn" {
  value       = module.karpenter.iam_role_arn
  description = "The ARN of the Karpenter Controller role that was created."
}

output "karpenter-node-role-arn" {
  value       = module.karpenter.node_iam_role_arn
  description = "The Amazon Resource Name (ARN) specifying the node IAM role"
}

output "eks-deploy-role-arn" {
  value       = module.iam_github_oidc_role.arn
  description = "The ARN of the role that Github Actions will use to connect to the cluster."
}

output "karpenter-sqs-queue-name" {
  value = module.karpenter.queue_name
}

output "eks-cluster-name" {
  value = module.company-example-eks.cluster_name
}

output "eks-cluster-endpoint" {
  value = module.company-example-eks.cluster_endpoint
}
