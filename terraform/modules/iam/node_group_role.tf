# Node group role

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

#Policy attachment for Node Group Role

resource "aws_iam_role_policy_attachment" "node_group_role_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#EC2 Container Registry (ECR) Read-Only Policy Attachment for Node Group Role

resource "aws_iam_role_policy_attachment" "node_group_role_ecr_readonly_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --------------------------------------------------------------------
# Amazon EKS CNI Policy
#
# Purpose:
# Allows worker nodes to manage pod networking by creating and managing
# Elastic Network Interfaces (ENIs) and assigning IP addresses.
# --------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

