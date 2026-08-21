data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      var.postgres_secret_arn
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name = "jenkins-external-secrets-policy"

  policy = data.aws_iam_policy_document.external_secrets.json
}