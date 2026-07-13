# EKS Cluster Role Variables

variable "node_group_role_name" {
  description = "Name of the EKS managed node group IAM role."
  type        = string
}

variable "eks_cluster_role_name" {
  description = "Name of the EKS cluster role"
  type        = string
}