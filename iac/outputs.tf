output "karpenter-controller-role-arn" {
  value       = module.karpenter.iam_role_arn
  description = "The ARN of the Karpenter Controller role that was created."
}

output "eks-deploy-role-arn" {
  value       = module.iam_github_oidc_role.arn
  description = "The ARN of the Karpenter Node role that was created."
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
## An empty comment to trigger the deployment
