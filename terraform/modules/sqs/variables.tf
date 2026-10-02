# -----------------------------------------------------------------------------
#
# SQS Module Variables
#
# Purpose:
# Defines the configuration inputs required by the SQS module.
#
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt SQS queues."
  type        = string
}