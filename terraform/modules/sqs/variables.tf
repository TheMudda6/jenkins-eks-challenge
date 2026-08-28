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