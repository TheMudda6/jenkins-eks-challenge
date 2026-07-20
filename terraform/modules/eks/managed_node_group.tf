# -----------------------------------------------------------------------------
# Amazon EKS Managed Node Group
#
# Purpose:
# Creates a managed group of Amazon EC2 instances that join the EKS cluster
# as Kubernetes worker nodes.
#
# These worker nodes run application workloads while the EKS control plane
# manages scheduling and the overall state of the cluster.
# -----------------------------------------------------------------------------

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  # -----------------------------------------------------------------------------
# Node Group Scaling
#
# Purpose:
# Defines the minimum, desired and maximum number of worker nodes that
# Auto Scaling can maintain for the cluster.
# -----------------------------------------------------------------------------

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # -----------------------------------------------------------------------------
# EC2 Instance Type
#
# Purpose:
# Defines the EC2 instance type used for the worker nodes.
# -----------------------------------------------------------------------------

  instance_types = [var.instance_type]

  tags = merge(var.tags, {
    "Name" = "${var.cluster_name}-node-group"
  })
}