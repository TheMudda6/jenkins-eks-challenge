# --------------------------------------------------------------------------------------
# EKS Worker Node IAM Role
#
# Purpose:
# IAM role assumed by EC2 instances in the EKS Managed Node Group.
#
# This role allows worker nodes to join the Kubernetes cluster,
# pull container images from Amazon ECR and manage pod networking.
# --------------------------------------------------------------------------------------

resource "aws_iam_role" "node_group_role" {
  name = var.node_group_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# --------------------------------------------------------------------------------------
# Amazon EKS Worker Node Policy
#
# Purpose:
# Allows EC2 worker nodes to register with and communicate
# with the Kubernetes control plane.
# --------------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# --------------------------------------------------------------------------------------
# Amazon ECR ReadOnly Policy
#
# Purpose:
# Allows worker nodes to pull container images
# from Amazon Elastic Container Registry.
# -----------------------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "amazon_ecr_readonly_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --------------------------------------------------------------------------------------
# Amazon EKS CNI Policy
#
# Purpose:
# Allows worker nodes to manage pod networking by creating and managing
# Elastic Network Interfaces (ENIs) and assigning IP addresses.
# --------------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

