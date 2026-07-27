# Namespace

variable "aws_load_balancer_controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller will be installed."
  type        = string
}

# Cluster Name

variable "cluster_name" {
  description = "Name of the EKS cluster the controller will manage."
  type        = string
}

# AWS Load Balancer Controller Role ARN

variable "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller."
  type        = string
}

#  AWS Load Balancer controller version

variable "aws_load_balancer_controller_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart."
  type        = string
}

# AWS Region

variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed."
  type        = string
}

# VPC ID

variable "vpc_id" {
  description = "VPC ID used by the AWS Load Balancer Controller."
  type        = string
}