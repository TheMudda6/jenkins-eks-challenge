# -----------------------------------------------------------------------------
# Application IAM Role for Service Accounts (IRSA)
#
# Purpose:
# Creates the IAM Role and IAM Policy required by the application running
# inside Kubernetes. This allows the application to publish messages to
# Amazon SQS without storing AWS credentials inside the cluster.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Assume Role Policy
#
# Purpose:
# Defines which Kubernetes Service Account is allowed to assume this IAM Role
# using the cluster's OpenID Connect (OIDC) provider.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "application_assume_role" {

  statement {

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {

      test = "StringEquals"

      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.application_namespace}:${var.application_service_account_name}"
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Role
#
# Purpose:
# Creates the IAM Role assumed by the application Service Account.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "application_role" {

  name = var.application_role_name

  assume_role_policy = data.aws_iam_policy_document.application_assume_role.json
}

# -----------------------------------------------------------------------------
# IAM Policy
#
# Purpose:
# Grants the application permission to publish messages to Amazon SQS.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "application_sqs_policy" {

  statement {

    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]

    resources = [
      var.orders_queue_arn
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy
#
# Purpose:
# Creates the IAM Policy granting the application permission to publish
# messages to the orders SQS queue.
# -----------------------------------------------------------------------------


resource "aws_iam_policy" "application_policy" {

  name = var.application_policy_name

  policy = data.aws_iam_policy_document.application_sqs_policy.json
}

# -----------------------------------------------------------------------------
# IAM Policy Attachment
#
# Purpose:
# Attaches the SQS IAM Policy to the application IAM Role.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "application_policy_attachment" {

  role = aws_iam_role.application_role.name

  policy_arn = aws_iam_policy.application_policy.arn
}