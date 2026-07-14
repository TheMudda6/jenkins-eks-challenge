# -----------------------------------------------------------------------------
# Amazon EBS CSI Driver IAM Role for Service Accounts (IRSA)
#
# Purpose:
# Creates the IAM Role used by the Amazon EBS CSI Driver running inside
# Kubernetes. This allows the CSI Driver to manage Amazon EBS volumes
# securely without storing AWS credentials inside the cluster.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Assume Role Policy
#
# Purpose:
# Defines which Kubernetes Service Account is allowed to assume this IAM Role
# using the cluster's OpenID Connect (OIDC) provider.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ebs_csi_assume_role" {
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
        "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      ]
    }

    effect = "Allow"
  }
}

# -----------------------------------------------------------------------------
# IAM Role
#
# Purpose:
# Creates the IAM Role assumed by the EBS CSI Driver Service Account.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

# -----------------------------------------------------------------------------
# IAM Policy Attachment
#
# Purpose:
# Attaches the AWS managed AmazonEBSCSIDriverPolicy to the IAM Role,
# granting permissions to create, attach, detach and manage Amazon
# EBS volumes.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}