# -----------------------------------------------------------------------------
# Root Module Variables
#
# Purpose:
# Defines the user-configurable inputs for the Jenkins EKS platform.
# These values are passed into the VPC, IAM and EKS modules.
# -----------------------------------------------------------------------------

# =============================================================================
# AWS Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Region
#
# Purpose:
# Defines the AWS region where all infrastructure will be deployed.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-2"
}

# =============================================================================
# Project Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# Environment
#
# Purpose:
# Identifies the deployment environment (e.g. development, staging, production).
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment."
  type        = string
}

# -----------------------------------------------------------------------------
# Project Name
#
# Purpose:
# Defines the project name used for resource naming and tagging.
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource tagging."
  type        = string
}

# -----------------------------------------------------------------------------
# Owner
#
# Purpose:
# Identifies the owner of the infrastructure.
# -----------------------------------------------------------------------------

variable "owner" {
  description = "Owner of the infrastructure."
  type        = string
}

# -----------------------------------------------------------------------------
# Common Resource Tags
#
# Purpose:
# Defines tags applied to AWS resources across the platform.
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)

  default = {
    ManagedBy = "Terraform"
  }
}

# =============================================================================
# VPC Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Name
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC."
  type        = string
}

# -----------------------------------------------------------------------------
# VPC CIDR
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

# -----------------------------------------------------------------------------
# Availability Zones
# -----------------------------------------------------------------------------

variable "availability_zones" {
  description = "Availability Zones where the VPC subnets will be created."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

# =============================================================================
# IAM Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------

variable "eks_cluster_role_name" {
  description = "Name of the EKS Cluster IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# EKS Node Group IAM Role
# -----------------------------------------------------------------------------

variable "node_group_role_name" {
  description = "Name of the EKS managed node group IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# Amazon EBS CSI Driver IAM Role
# -----------------------------------------------------------------------------

variable "ebs_csi_driver_role_name" {
  description = "Name of the IAM Role for the Amazon EBS CSI Driver."
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_role_name" {
  description = "Name of the IAM Role for the AWS Load Balancer Controller."
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Policy
# -----------------------------------------------------------------------------

variable "aws_load_balancer_controller_policy_name" {
  description = "Name of the IAM Policy for the AWS Load Balancer Controller."
  type        = string
}

# =============================================================================
# EKS Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Name
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "jenkins-eks"
}

# -----------------------------------------------------------------------------
# Kubernetes Version
# -----------------------------------------------------------------------------

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

# -----------------------------------------------------------------------------
# Worker Node Instance Type
# -----------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type for the EKS worker nodes."
  type        = string
  default     = "t3.small"
}

# -----------------------------------------------------------------------------
# Minimum Worker Nodes
# -----------------------------------------------------------------------------

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Desired Worker Nodes
# -----------------------------------------------------------------------------

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Maximum Worker Nodes
# -----------------------------------------------------------------------------

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 2
}