# -----------------------------------------------------------------------------
# Node Group Role Name
#
# Purpose:
# Defines the name of the EKS managed node group IAM role.
# -----------------------------------------------------------------------------

variable "node_group_role_name" {
  description = "Name of the EKS managed node group IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# EKS Cluster Role Name
#
# Purpose:
# Defines the name of the EKS cluster IAM role.
# -----------------------------------------------------------------------------

variable "eks_cluster_role_name" {
  description = "Name of the EKS cluster role"
  type        = string
}

# -----------------------------------------------------------------------------
# OIDC Provider ARN
#
# Purpose:
# Defines the ARN of the EKS OIDC provider.
# -----------------------------------------------------------------------------

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

# -----------------------------------------------------------------------------
# Cluster OIDC Issuer URL
#
# Purpose:
# Defines the OpenID Connect (OIDC) issuer URL for the EKS cluster. This is used to create IAM Roles for Service Accounts (IRSA) that allow Kubernetes Service Accounts to assume IAM Roles.
# -----------------------------------------------------------------------------

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

# -----------------------------------------------------------------------------
# EBS CSI Driver IAM Role Name
#
# Purpose:
# Defines the name of the EBS CSI Driver IAM Role created for the EKS cluster.
# -----------------------------------------------------------------------------

variable "ebs_csi_driver_role_name" {
  description = "Name of the IAM Role for the EBS CSI Driver"
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role Name
#
# Purpose:
# Defines the name of the IAM Role created for the AWS Load Balancer Controller.
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_role_name" {
  description = "Name of the IAM Role for the AWS Load Balancer Controller"
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Policy Name
#
# Purpose:
# Defines the name of the IAM Policy created for the AWS Load Balancer Controller.
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_policy_name" {
  description = "Name of the IAM Policy for the AWS Load Balancer Controller"
  type        = string
}