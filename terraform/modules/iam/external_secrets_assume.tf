data "aws_iam_policy_document" "external_secrets_assume" {

  statement {
    effect = "Allow"

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