# -----------------------------------------------------------------------------
#
# ECR Module Variables
#
# Purpose:
# Defines the configuration inputs required by the ECR module.
#
# -----------------------------------------------------------------------------

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt ECR repositories."
  type        = string
}