# --------------------------------------------------------------------
# GitHub OIDC Provider
#
# Purpose:
# Allow GitHub Actions to authenticate with AWS using OpenID Connect
# instead of long-lived AWS access keys.
# --------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "ffffffffffffffffffffffffffffffffffffffff"
  ]
}

# --------------------------------------------------------------------
# GitHub Actions Trust Policy
#
# Purpose:
# Allow GitHub Actions workflows from this repository to assume the
# GitHub Actions IAM Role using OIDC.
# --------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:TheMudda6/jenkins-eks-challenge:*"
      ]
    }

  }

}

# --------------------------------------------------------------------
# GitHub Actions IAM Role
#
# Purpose:
# IAM Role assumed by GitHub Actions using OpenID Connect.
# --------------------------------------------------------------------

resource "aws_iam_role" "github_actions_oidc_role" {

  name = var.github_actions_oidc_role_name

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

}

# --------------------------------------------------------------------
# GitHub Actions ECR Policy
#
# Purpose:
# Allow GitHub Actions to authenticate with Amazon ECR and
# push application container images.
# --------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_ecr_policy" {

  statement {

    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }

  statement {

    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage"
    ]

    resources = [
      var.ecr_repository_arn
    ]
  }
}

# --------------------------------------------------------------------
# GitHub Actions IAM Policy
#
# Purpose:
# Allow GitHub Actions to push Docker images to Amazon ECR.
# --------------------------------------------------------------------

resource "aws_iam_policy" "github_actions_ecr_policy" {

  name = "github-actions-ecr-policy"

  policy = data.aws_iam_policy_document.github_actions_ecr_policy.json

}

# --------------------------------------------------------------------
# GitHub Actions Policy Attachment
#
# Purpose:
# Attach the ECR policy to the GitHub Actions IAM Role.
# --------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_actions_ecr_policy" {

  role = aws_iam_role.github_actions_oidc_role.name

  policy_arn = aws_iam_policy.github_actions_ecr_policy.arn

}