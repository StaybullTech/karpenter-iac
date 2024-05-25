output "karpenter-controller-role-arn" {
  value       = module.karpenter.iam_role_arn
  description = "The ARN of the Karpenter Controller role that was created."
}

output "karpenter-node-role-arn" {
  value       = module.karpenter.node_iam_role_arn
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