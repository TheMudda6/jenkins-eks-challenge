output "node_role_arn" {
  description = "ARN of the IAM role used by Karpenter-provisioned nodes."
  value       = aws_iam_role.node.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile used by Karpenter."
  value       = aws_iam_instance_profile.node.name
}

output "controller_role_arn" {
  description = "ARN of the IAM role assumed by the Karpenter controller."
  value       = aws_iam_role.controller.arn
}

output "namespace" {
  description = "Namespace where Karpenter is installed."
  value       = helm_release.karpenter.namespace
}