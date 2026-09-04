# -----------------------------------------------------------------------------
#
# External Secrets IAM Policy
#
# Purpose:
# Defines the IAM permissions required by External Secrets Operator to
# retrieve PostgreSQL credentials from AWS Secrets Manager.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      var.postgres_secret_arn,
      var.grafana_secret_arn
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name = "jenkins-external-secrets-policy"

  policy = data.aws_iam_policy_document.external_secrets.json
}