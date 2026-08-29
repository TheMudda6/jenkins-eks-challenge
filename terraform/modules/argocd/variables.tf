# -----------------------------------------------------------------------------
#
# ArgoCD Module Variables
#
# Purpose:
# Defines the configuration inputs required by the ArgoCD module and its
# Jenkins Application definition.
#
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Namespace where ArgoCD will be installed."
  type        = string
}

variable "chart_version" {
  description = "Version of the ArgoCD Helm chart."
  type        = string
}
