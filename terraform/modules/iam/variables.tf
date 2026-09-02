# -----------------------------------------------------------------------------
#
# IAM Module Variables
#
# Purpose:
# Defines the configuration inputs required by the IAM module.
#
# These variables control the IAM roles, policies and trust relationships
# used by Amazon EKS, Kubernetes controllers, the application and GitHub
# Actions.
#
# -----------------------------------------------------------------------------

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
  description = "Name of the EKS cluster IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# OIDC Provider ARN
#
# Purpose:
# Defines the ARN of the EKS OIDC provider.
# -----------------------------------------------------------------------------

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider."
  type        = string
}

# -----------------------------------------------------------------------------
# Cluster OIDC Issuer URL
#
# Purpose:
# Defines the OpenID Connect (OIDC) issuer URL for the EKS cluster.
# This is used to create IAM Roles for Service Accounts (IRSA).
# allowING Kubernetes Service Accounts to assume IAM Roles.
# -----------------------------------------------------------------------------

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster."
  type        = string
}

# -----------------------------------------------------------------------------
# EBS CSI Driver IAM Role Name
#
# Purpose:
# Defines the name of the EBS CSI Driver IAM Role created for the EKS cluster.
# -----------------------------------------------------------------------------

variable "ebs_csi_driver_role_name" {
  description = "Name of the IAM Role for the EBS CSI Driver."
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role Name
#
# Purpose:
# Defines the name of the IAM Role created for the AWS Load Balancer Controller.
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_role_name" {
  description = "Name of the IAM Role for the AWS Load Balancer Controller."
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Policy Name
#
# Purpose:
# Defines the name of the IAM Policy created for the AWS Load Balancer Controller.
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_policy_name" {
  description = "Name of the IAM Policy for the AWS Load Balancer Controller."
  type        = string
}

# -----------------------------------------------------------------------------
# Application IRSA
# -----------------------------------------------------------------------------

variable "application_role_name" {
  description = "IAM Role name for the application."
  type        = string
}

variable "application_policy_name" {
  description = "IAM Policy name for the application."
  type        = string
}

variable "application_namespace" {
  description = "Kubernetes namespace where the application runs."
  type        = string
}

variable "application_service_account_name" {
  description = "Kubernetes Service Account used by the application."
  type        = string
}

variable "orders_queue_arn" {
  description = "ARN of the orders SQS queue."
  type        = string
}

# --------------------------------------------------------------------
# GitHub Actions
# --------------------------------------------------------------------

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository used by GitHub Actions."
  type        = string
}

variable "github_actions_oidc_role_name" {
  description = "Name of the IAM Role for GitHub Actions OIDC."
  type        = string
}

variable "postgres_secret_arn" {
  description = "ARN of the PostgreSQL secret stored in AWS Secrets Manager."
  type        = string
}
# -----------------------------------------------------------------------------
# Route 53 / ExternalDNS
# -----------------------------------------------------------------------------

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID managed by ExternalDNS and cert-manager."
  type        = string
}

variable "external_dns_role_name" {
  description = "IAM Role name for ExternalDNS."
  type        = string
}

variable "external_dns_policy_name" {
  description = "IAM Policy name for ExternalDNS."
  type        = string
}

# -----------------------------------------------------------------------------
# cert-manager
# -----------------------------------------------------------------------------

variable "cert_manager_role_name" {
  description = "IAM Role name for cert-manager."
  type        = string
}

variable "cert_manager_policy_name" {
  description = "IAM Policy name for cert-manager."
  type        = string
}
