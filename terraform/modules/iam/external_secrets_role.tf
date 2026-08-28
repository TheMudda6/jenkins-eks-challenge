# -----------------------------------------------------------------------------
#
# External Secrets IAM Role
#
# Purpose:
# Creates and attaches the IAM Role used by External Secrets Operator to
# access secrets stored in AWS Secrets Manager.
#
# -----------------------------------------------------------------------------

resource "aws_iam_role" "external_secrets" {
  name = "jenkins-external-secrets-role"

  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role = aws_iam_role.external_secrets.name

  policy_arn = aws_iam_policy.external_secrets.arn
}