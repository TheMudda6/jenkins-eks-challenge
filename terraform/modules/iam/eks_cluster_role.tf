# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
#
# Purpose:
# IAM role assumed by the Amazon EKS control plane.
#
# This role allows AWS to manage the Kubernetes control plane,
# including communication with worker nodes and other AWS services
# required by the cluster.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = var.eks_cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster Policy Attachment
#
# Purpose:
# Attaches the AWS-managed AmazonEKSClusterPolicy to the EKS Cluster IAM Role.
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

