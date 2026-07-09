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
  description = "The name of the project for which the VPC is being created"
  type        = string
}

variable "owner" {
  description = "The owner of the VPC"
  type        = string
}