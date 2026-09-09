# -----------------------------------------------------------------------------
# ExternalDNS Route 53 IAM Role for Service Accounts (IRSA)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:external-dns:external-dns"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "external_dns_route53" {
  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListTagsForResources"
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
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "external_dns" {
  name               = var.external_dns_role_name
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_policy" "external_dns_route53" {
  name   = var.external_dns_policy_name
  policy = data.aws_iam_policy_document.external_dns_route53.json
}

resource "aws_iam_role_policy_attachment" "external_dns_route53" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns_route53.arn
}