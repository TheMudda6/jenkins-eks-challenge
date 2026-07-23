# Namespace

variable "namespace" {
  description = "Namespace where the AWS Load Balancer Controller will be installed."
  type        = string
}

# Cluster Name

variable "cluster_name" {
  description = "Name of the EKS cluster the controller will manage."
  type        = string
}

# ALB Ingress Controller version

variable "alb_ingress_controller_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart."
  type        = string
}

# AWS Load Balancer Controller Role ARN

variable "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller."
  type        = string
}