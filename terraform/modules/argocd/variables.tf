variable "namespace" {
  description = "Namespace where ArgoCD will be installed."
  type        = string
}

variable "chart_version" {
  description = "Version of the ArgoCD Helm chart."
  type        = string
}