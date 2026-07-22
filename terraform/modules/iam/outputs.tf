# -----------------------------------------------------------------------------
# IAM Module Outputs
#
# Purpose:
# Exposes the IAM role ARNs so other modules can consume them.
# -----------------------------------------------------------------------------

output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn

  description = "ARN of the EKS cluster IAM role."
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group_role.arn

  description = "ARN of the EKS managed node group IAM role."
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller_role.arn

  description = "ARN of the AWS Load Balancer Controller IAM Role"
}

output "ebs_csi_driver_role_arn" {
  value = aws_iam_role.ebs_csi_driver_role.arn

  description = "ARN of the EBS CSI Driver IAM Role"
}


