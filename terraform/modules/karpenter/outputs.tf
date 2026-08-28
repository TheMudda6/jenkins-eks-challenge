output "node_role_arn" {
  description = "ARN of the IAM role used by Karpenter-provisioned nodes."
  value       = aws_iam_role.node.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile used by Karpenter."
  value       = aws_iam_instance_profile.node.name
}