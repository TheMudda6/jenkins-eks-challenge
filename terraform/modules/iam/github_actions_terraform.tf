# --------------------------------------------------------------------
# GitHub Actions Terraform IAM Role
#
# Purpose:
# Dedicated role for infrastructure Terraform deployments.
# This role reuses the existing GitHub OIDC provider and trust policy
# but remains separate from the application/ECR GitHub Actions role.
# --------------------------------------------------------------------

resource "aws_iam_role" "github_actions_terraform" {
  name = var.github_actions_terraform_role_name

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_policy_document" "github_actions_terraform" {
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::mudassir-tf-state-893061519920"
    ]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::mudassir-tf-state-893061519920/jenkins/terraform.tfstate"
    ]
  }

  statement {
    sid    = "TerraformStateLock"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::mudassir-tf-state-893061519920/jenkins/terraform.tfstate.tflock"
    ]
  }

  statement {
    sid    = "EKSAccess"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:AccessKubernetesApi"
    ]

    resources = [
      "arn:aws:eks:eu-west-2:893061519920:cluster/jenkins-eks"
    ]
  }

  statement {
    sid    = "PassEksServiceRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::893061519920:role/jenkins-eks-cluster-role",
      "arn:aws:iam::893061519920:role/jenkins-node-group-role",
      "arn:aws:iam::893061519920:role/jenkins-ebs-csi-driver-role"
    ]
  }

  statement {
    sid    = "ManageEksInfrastructure"
    effect = "Allow"

    actions = [
      "eks:CreateCluster",
      "eks:DescribeCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:DeleteCluster",
      "eks:ListClusters",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:CreateNodegroup",
      "eks:DescribeNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "eks:DeleteNodegroup",
      "eks:ListNodegroups",
      "eks:CreateAddon",
      "eks:DescribeAddon",
      "eks:UpdateAddon",
      "eks:DeleteAddon",
      "eks:ListAddons",
      "eks:CreateAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:UpdateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:ListAccessEntries",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:ListAssociatedAccessPolicies",
      "eks:ListAccessPolicies"
    ]

    resources = [
      "arn:aws:eks:eu-west-2:893061519920:cluster/jenkins-eks",
      "arn:aws:eks:eu-west-2:893061519920:nodegroup/jenkins-eks/*",
      "arn:aws:eks:eu-west-2:893061519920:addon/jenkins-eks/*",
      "arn:aws:eks:eu-west-2:893061519920:access-entry/jenkins-eks/*"
    ]
  }

  statement {
    sid    = "ManageNetworking"
    effect = "Allow"

    actions = [
      "ec2:CreateVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
      "ec2:DeleteVpc",

      "ec2:CreateSubnet",
      "ec2:DescribeSubnets",
      "ec2:ModifySubnetAttribute",
      "ec2:DeleteSubnet",

      "ec2:CreateInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DeleteInternetGateway",

      "ec2:CreateRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:ReplaceRoute",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",

      "ec2:AllocateAddress",
      "ec2:DescribeAddresses",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",

      "ec2:CreateNatGateway",
      "ec2:DescribeNatGateways",
      "ec2:DeleteNatGateway",

      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "ManageIamResources"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",

      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagPolicy",
      "iam:UntagPolicy",

      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",

      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy"
    ]

    resources = [
      "arn:aws:iam::893061519920:role/jenkins-*",
      "arn:aws:iam::893061519920:role/github-actions-*",
      "arn:aws:iam::893061519920:policy/jenkins-*",
      "arn:aws:iam::893061519920:policy/github-actions-*"
    ]
  }

  statement {
    sid    = "ManageEcrRepositories"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:PutLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:GetLifecyclePolicy",
      "ecr:ListTagsForResource",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]

    resources = [
      "arn:aws:ecr:eu-west-2:893061519920:repository/jenkins-eks-challenge-dev-*"
    ]
  }

  statement {
    sid    = "ManageSqsQueues"
    effect = "Allow"

    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:ListQueueTags"
    ]

    resources = [
      "arn:aws:sqs:eu-west-2:893061519920:jenkins-eks-challenge-dev-*"
    ]
  }

  statement {
    sid    = "ManageSecretsManager"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = [
      "arn:aws:secretsmanager:eu-west-2:893061519920:secret:jenkins-*"
    ]
  }
}

# --------------------------------------------------------------------
# GitHub Actions Terraform IAM Policy
#
# Purpose:
# Attach the Terraform permissions to the dedicated GitHub Actions
# Terraform IAM Role.
# --------------------------------------------------------------------

resource "aws_iam_policy" "github_actions_terraform" {
  name   = "github-actions-terraform-policy"
  policy = data.aws_iam_policy_document.github_actions_terraform.json
}

# --------------------------------------------------------------------
# GitHub Actions Terraform Policy Attachment
#
# Purpose:
# Attach the Terraform policy to the dedicated Terraform deployment
# role.
# --------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.github_actions_terraform.arn
}