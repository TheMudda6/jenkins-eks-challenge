# -----------------------------------------------------------------------------
# Amazon EKS Cluster
#
# Purpose:
# Creates the Amazon Elastic Kubernetes Service (EKS) control plane.
#
# The control plane manages the Kubernetes API server and cluster state,
# while worker nodes run the application workloads.
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}