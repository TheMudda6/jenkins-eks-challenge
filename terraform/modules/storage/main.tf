#
# Amazon EBS CSI Driver
#
# Purpose:
# Installs the AWS-managed EBS CSI Driver
# add-on into the EKS cluster. This enables
# Kubernetes workloads to dynamically provision
# and manage Amazon EBS volumes through
# PersistentVolumeClaims.
#

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_role_arn

  tags = {
    Name        = "ebs-csi-driver"
    Project     = "jenkins-on-eks"
    Environment = "dev"
  }
}

#
# Default EBS Storage Class
#
# Purpose:
# Defines how Kubernetes dynamically provisions
# persistent storage using the Amazon EBS CSI
# Driver whenever a PersistentVolumeClaim is
# created without specifying another
# StorageClass.
#

resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp3"
  }

  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  depends_on = [
    aws_eks_addon.ebs_csi_driver
  ]
}