# -----------------------------------------------------------------------------
# Karpenter Controller IAM Role
#
# Purpose:
# IAM role assumed by the Karpenter controller through EKS IRSA.
#
# This allows Karpenter to discover and manage EC2 capacity on behalf of
# Kubernetes workloads.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "controller_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        var.oidc_provider_arn
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:kube-system:karpenter"
      ]
    }
  }
}

resource "aws_iam_role" "controller" {
  name = "${var.cluster_name}-karpenter-controller-role"

  assume_role_policy = data.aws_iam_policy_document.controller_assume_role.json
}

# -----------------------------------------------------------------------------
# Karpenter Controller IAM Policy
#
# Purpose:
# Grants Karpenter the AWS permissions required to discover, create,
# configure and terminate EC2 capacity.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "controller" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:*:*:parameter/aws/service/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "pricing:GetProducts"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.node.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [
      "arn:aws:eks:*:*:cluster/${var.cluster_name}"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:ListInstanceProfiles",
      "iam:GetInstanceProfile"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "controller" {
  name = "${var.cluster_name}-karpenter-controller-policy"

  policy = data.aws_iam_policy_document.controller.json
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}