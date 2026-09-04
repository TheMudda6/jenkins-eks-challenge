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