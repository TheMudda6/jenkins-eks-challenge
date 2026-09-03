# -----------------------------------------------------------------------------
# Event Bus IRSA Roles
#
# Producers can publish events to the orders queue.
# The worker can receive, inspect and delete messages from the queue.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "event_producer_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.application_namespace}:order-service",
        "system:serviceaccount:${var.application_namespace}:payment-service",
        "system:serviceaccount:${var.application_namespace}:shipping-service"
      ]
    }
  }
}

resource "aws_iam_role" "event_producer_role" {
  name               = var.event_producer_role_name
  assume_role_policy = data.aws_iam_policy_document.event_producer_assume_role.json
}

data "aws_iam_policy_document" "event_producer_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      var.orders_queue_arn
    ]
  }
}

resource "aws_iam_policy" "event_producer_policy" {
  name   = var.event_producer_policy_name
  policy = data.aws_iam_policy_document.event_producer_policy.json
}

resource "aws_iam_role_policy_attachment" "event_producer_policy" {
  role       = aws_iam_role.event_producer_role.name
  policy_arn = aws_iam_policy.event_producer_policy.arn
}

data "aws_iam_policy_document" "event_worker_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.application_namespace}:worker"
      ]
    }
  }
}

resource "aws_iam_role" "event_worker_role" {
  name               = var.event_worker_role_name
  assume_role_policy = data.aws_iam_policy_document.event_worker_assume_role.json
}

data "aws_iam_policy_document" "event_worker_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]

    resources = [
      var.orders_queue_arn
    ]
  }
}

resource "aws_iam_policy" "event_worker_policy" {
  name   = var.event_worker_policy_name
  policy = data.aws_iam_policy_document.event_worker_policy.json
}

resource "aws_iam_role_policy_attachment" "event_worker_policy" {
  role       = aws_iam_role.event_worker_role.name
  policy_arn = aws_iam_policy.event_worker_policy.arn
}
