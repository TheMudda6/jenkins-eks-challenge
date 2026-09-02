# -----------------------------------------------------------------------------
#
# Terraform DNS Variables
#
# Purpose:
# Defines configuration for the dedicated Jenkins Route 53 hosted zone.
#
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region used for Terraform provider configuration."
  type        = string
}

variable "jenkins_zone_name" {
  description = "Route 53 hosted zone name delegated to Jenkins."
  type        = string

  validation {
    condition     = trimspace(var.jenkins_zone_name) != ""
    error_message = "jenkins_zone_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment used for resource tagging."
  type        = string
}
