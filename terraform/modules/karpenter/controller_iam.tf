# -----------------------------------------------------------------------------
# Karpenter Controller IAM Role
#
# Purpose:
# IAM role assumed by the Karpenter controller through EKS IRSA.
#
# This allows Karpenter to discover and manage EC2 capacity on behalf of
# Kubernetes workloads.
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

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

# ---------------------------------------------------------------------------
# EC2 launch resource access
#
# Karpenter may read the EC2 resources required to launch capacity.
# These permissions follow Karpenter 1.6.5's scoped CreateFleet/RunInstances
# model rather than granting EC2 launch access across arbitrary resources.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "controller" {
  # ---------------------------------------------------------------------------
  # EC2 launch resource access
  #
  # Scope RunInstances/CreateFleet to the EC2 resources Karpenter may use
  # when launching capacity.
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}::image/*",
      "arn:aws:ec2:${data.aws_region.current.name}::snapshot/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:security-group/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:subnet/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:capacity-reservation/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:placement-group/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"

      values = [
        "*"
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate"
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:fleet/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:volume/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:network-interface/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*",
      "arn:aws:ec2:${data.aws_region.current.name}:*:spot-instances-request/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"

      values = [
        var.cluster_name
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # EC2 launch-template lifecycle
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate"
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:launch-template/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # EC2 instance lifecycle
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "ec2:TerminateInstances"
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:*:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Regional EC2 resource discovery
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"

      values = [
        data.aws_region.current.name
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # SSM parameter discovery
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:*:*:parameter/aws/service/*"
    ]
  }

  # ---------------------------------------------------------------------------
  # Pricing discovery
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "pricing:GetProducts"
    ]

    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # Node IAM role passing
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.node.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ec2.amazonaws.com",
        "ec2.amazonaws.com.cn"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # EKS cluster discovery
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:*:cluster/${var.cluster_name}"
    ]
  }

  # ---------------------------------------------------------------------------
  # Instance profile creation
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "iam:CreateInstanceProfile"
    ]

    resources = [
      "arn:aws:iam::*:instance-profile/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"

      values = [
        var.cluster_name
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"

      values = [
        data.aws_region.current.name
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Instance profile tagging
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "iam:TagInstanceProfile"
    ]

    resources = [
      "arn:aws:iam::*:instance-profile/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"

      values = [
        data.aws_region.current.name
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"

      values = [
        var.cluster_name
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"

      values = [
        data.aws_region.current.name
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"

      values = [
        "*"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Instance profile lifecycle
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile"
    ]

    resources = [
      "arn:aws:iam::*:instance-profile/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"

      values = [
        "owned"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"

      values = [
        data.aws_region.current.name
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"

      values = [
        "*"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Instance profile discovery
  # ---------------------------------------------------------------------------

  statement {
    effect = "Allow"

    actions = [
      "iam:GetInstanceProfile"
    ]

    resources = [
      "arn:aws:iam::*:instance-profile/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:ListInstanceProfiles"
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
