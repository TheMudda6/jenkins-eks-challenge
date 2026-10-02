# -----------------------------------------------------------------------------
#
# AWS KMS Module Variables
#
# Purpose:
# Defines the project and environment values used to name and tag
# customer-managed KMS resources.
#
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for KMS resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment used for KMS resource tagging."
  type        = string
}