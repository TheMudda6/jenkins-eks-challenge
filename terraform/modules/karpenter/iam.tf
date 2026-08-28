# -----------------------------------------------------------------------------
# Karpenter Node IAM Role
#
# Purpose:
# IAM role assumed by EC2 instances provisioned by Karpenter.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Karpenter Node IAM Policies
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -----------------------------------------------------------------------------
# Karpenter Instance Profile
#
# Karpenter uses the instance profile when launching EC2 worker nodes.
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-karpenter-node-instance-profile"
  role = aws_iam_role.node.name
}