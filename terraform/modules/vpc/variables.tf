# -----------------------------------------------------------------------------
# VPC Name
#
# Purpose:
# Defines the name assigned to the Virtual Private Cloud.
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