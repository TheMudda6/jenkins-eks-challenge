#
# Storage Module Variables
#
# Purpose:
# Defines the inputs required by the Storage
# module. These values are supplied by the
# root module and other infrastructure modules.
#

# Cluster Name

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# EBS CSI Role ARN

variable "ebs_csi_role_arn" {
  description = "IAM Role ARN used by the EBS CSI Driver"
  type        = string
}