# -----------------------------------------------------------------------------
#
# External Secrets IAM Trust Policy
#
# Purpose:
# Defines the trust relationship that allows the External Secrets Operator
# Kubernetes Service Account to assume its IAM Role using EKS OIDC and IRSA.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_secrets_assume" {

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        var.oidc_provider_arn
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:external-secrets:external-secrets"
      ]
    }
  }
}