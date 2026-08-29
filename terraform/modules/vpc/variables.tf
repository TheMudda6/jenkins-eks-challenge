# -----------------------------------------------------------------------------
#
# VPC Module Variables
#
# Purpose:
# Defines the configuration inputs required by the VPC module.
#
# These variables control the VPC address space, Availability Zones,
# public and private subnet configuration, and common resource tagging.
#
# -----------------------------------------------------------------------------

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "A list of availability zones in which to create subnets"
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "A list of CIDR blocks for public subnets"
  type        = list(string)
}

variable "environment" {
  description = "The environment in which the VPC is deployed"
  type        = string
}

variable "project_name" {
  description = "Project name used for naming and tagging resources."
  type        = string
}

variable "owner" {
  description = "Project owner used for resource tagging."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster used for Karpenter resource discovery."
  type        = string
}