# -----------------------------------------------------------------------------
#
# Secrets Module Variables
#
# Purpose:
# Defines the sensitive configuration inputs required by the Secrets
# Manager module.
#
# -----------------------------------------------------------------------------

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana administrator password."
  type        = string
  sensitive   = true
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt Secrets Manager secrets."
  type        = string
}