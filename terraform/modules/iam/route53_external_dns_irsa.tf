# -----------------------------------------------------------------------------
#
# ExternalDNS Route 53 IAM Role for Service Accounts (IRSA)
#
# Purpose:
# Creates the IAM Role and policy used by ExternalDNS to manage DNS records
# in the dedicated Jenkins Route 53 hosted zone.
#
# Access is restricted to the Jenkins hosted zone and the ExternalDNS
# Kubernetes Service Account.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_dns_assume_role" {
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
        "system:serviceaccount:external-dns:external-dns"
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
# ExternalDNS IAM Policy
#
# Purpose:
# Allows ExternalDNS to list, create, update and delete records only inside
# the dedicated Jenkins Route 53 hosted zone.
#
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_dns" {
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
      "route53:ListHostedZones"
    ]

    resources = [
      "*"
    ]
  }
}

# -----------------------------------------------------------------------------
# ExternalDNS IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "external_dns" {
  name = var.external_dns_role_name

  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_policy" "external_dns" {
  name   = var.external_dns_policy_name
  policy = data.aws_iam_policy_document.external_dns.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}
