# -----------------------------------------------------------------------------
# TLS Certificate
#
# Purpose:
# Retrieves the TLS certificate for the EKS OIDC issuer.
# The certificate thumbprint is required when creating the
# IAM OpenID Connect Provider.
# -----------------------------------------------------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# -----------------------------------------------------------------------------
# IAM OIDC Provider
#
# Purpose:
# Creates an IAM OpenID Connect Provider for the EKS cluster.
# This allows Kubernetes Service Accounts to assume IAM Roles
# using IAM Roles for Service Accounts (IRSA).
# -----------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "main" {

  # Allow AWS Security Token Service (STS) to trust this OIDC provider.

  client_id_list = [
    "sts.amazonaws.com"
  ]

# Use the EKS OIDC provider's TLS certificate thumbprint.

  thumbprint_list = [
    data.tls_certificate.eks.certificates[0].sha1_fingerprint
  ]

  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}