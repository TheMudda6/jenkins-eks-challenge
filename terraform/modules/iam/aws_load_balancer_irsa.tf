# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role for Service Accounts (IRSA)
#
# Purpose:
# Creates the IAM Role and IAM Policy required by the AWS Load Balancer
# Controller running inside Kubernetes. This allows the controller to create,
# manage and delete AWS Application Load Balancers without storing AWS
# credentials inside the cluster.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Assume Role Policy
#
# Purpose:
# Defines which Kubernetes Service Account is allowed to assume this IAM Role
# using the cluster's OpenID Connect (OIDC) provider.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Role
#
# Purpose:
# Creates the IAM Role that the AWS Load Balancer Controller Kubernetes Service
# Account assumes via IAM Roles for Service Accounts (IRSA).
# -----------------------------------------------------------------------------

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = var.aws_load_balancer_controller_role_name
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

# -----------------------------------------------------------------------------
# IAM Policy
#
# Purpose:
# Creates the IAM Policy required by the AWS Load Balancer Controller.
#
# The policy is stored separately in iam_policy.json because it is based on the
# official AWS Load Balancer Controller IAM policy published by AWS.
#
# Review the upstream policy when upgrading the controller version to ensure
# any new permissions are incorporated.
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = var.aws_load_balancer_controller_policy_name
  policy = file("${path.module}/iam_policy.json")
}

# -----------------------------------------------------------------------------
# IAM Policy Attachment
#
# Purpose:
# Attaches the AWS Load Balancer Controller IAM Policy to the IAM Role,
# granting the controller permission to manage AWS load balancing resources.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}