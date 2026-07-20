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

# -----------------------------------------------------------------------------
# Amazon EBS CSI Driver Add-on
#
# Purpose:
# Installs the Amazon EBS CSI Driver into the EKS cluster.
#
# This add-on enables Kubernetes Persistent Volumes backed by
# Amazon Elastic Block Store (EBS).
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_driver_role_arn

  # Overwrite existing add-on configuration if it already exists.

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}