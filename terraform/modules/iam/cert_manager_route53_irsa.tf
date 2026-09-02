# -----------------------------------------------------------------------------
#
# cert-manager Route 53 IAM Role for Service Accounts (IRSA)
#
# Purpose:
# Creates the IAM Role and policy used by cert-manager to complete
# Let's Encrypt DNS-01 challenges using Route 53.
#
# Access is restricted to the dedicated Jenkins Route 53 hosted zone.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cert_manager_assume_role" {
  statement {
    effect = "Allow"

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
        "system:serviceaccount:cert-manager:cert-manager"
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# cert-manager IAM Policy
#
# Purpose:
# Allows cert-manager to create, update and delete ACME DNS-01 TXT records
# in the Jenkins Route 53 hosted zone and wait for Route 53 changes.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cert_manager_route53" {
  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = [
      "arn:aws:route53:::change/*"
    ]
  }
}

# -----------------------------------------------------------------------------
# cert-manager IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "cert_manager" {
  name = var.cert_manager_role_name

  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume_role.json
}

resource "aws_iam_policy" "cert_manager_route53" {
  name   = var.cert_manager_policy_name
  policy = data.aws_iam_policy_document.cert_manager_route53.json
}

resource "aws_iam_role_policy_attachment" "cert_manager_route53" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager_route53.arn
}
