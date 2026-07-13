# -----------------------------------------------------------------------------
# IAM Module Outputs
#
# Purpose:
# Exposes the IAM role ARNs so other modules can consume them.
# -----------------------------------------------------------------------------

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "node_group_role_arn" {
  description = "ARN of the EKS managed node group IAM role."
  value       = aws_iam_role.node_group_role.arn
}