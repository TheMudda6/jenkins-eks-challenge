# -----------------------------------------------------------------------------
# Root Module Variables
#
# Purpose:
# Defines the user-configurable inputs for the entire platform.
# These values are passed into the VPC, IAM and EKS modules.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Configuration
#
# Purpose:
# Defines the AWS region where the infrastructure will be deployed.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-2"
}

# -----------------------------------------------------------------------------
# VPC Variables
#
# Purpose:
# Networking configuration for the platform.
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones where the VPC subnets will be created."
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource tagging."
  type        = string
}

variable "owner" {
  description = "Owner of the infrastructure."
  type        = string
}

# -----------------------------------------------------------------------------
# IAM Variables
#
# Purpose:
# Defines the names of the IAM roles created for EKS.
# -----------------------------------------------------------------------------

variable "eks_cluster_role_name" {
  description = "Name of the EKS Cluster IAM role."
  type        = string
}

variable "node_group_role_name" {
  description = "Name of the EKS managed node group IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# EKS Variables
#
# Purpose:
# Defines the Kubernetes cluster configuration.
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "jenkins-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type for the EKS worker nodes."
  type        = string
  default     = "t3.small"
}

variable "tags" {
  description = "Common tags applied to AWS resources."
  type        = map(string)

  default = {
    ManagedBy = "Terraform"
  }
}