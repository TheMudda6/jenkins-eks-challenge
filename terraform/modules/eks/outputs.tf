# -----------------------------------------------------------------------------
# EKS Cluster Outputs
#
# Purpose:
# Exposes core EKS cluster information for use by other Terraform modules.
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS cluster."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_name" {
  description = "The name of the EKS managed node group."
  value       = aws_eks_node_group.main.node_group_name
}

# -----------------------------------------------------------------------------
# OIDC Issuer URL
#
# Purpose:
# Exposes the OIDC issuer URL so IAM roles can trust Kubernetes service accounts
# using IRSA.
# -----------------------------------------------------------------------------

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL used by IAM Roles for Service Accounts (IRSA)."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# -----------------------------------------------------------------------------
# OIDC Provider
#
# Purpose:
# Exposes the OIDC provider identifier (without the https:// prefix)
# for IAM trust policy conditions.
# -----------------------------------------------------------------------------

output "oidc_provider" {
  description = "OIDC provider identifier without the https:// prefix, used in IAM trust policy conditions."
  # AWS IAM trust policy condition keys require the OIDC issuer
  # without the https:// prefix.
  value = replace(
    aws_eks_cluster.main.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider."
  value       = aws_iam_openid_connect_provider.main.arn
}