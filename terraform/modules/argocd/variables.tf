variable "namespace" {
  description = "Namespace where ArgoCD will be installed."
  type        = string
}

variable "chart_version" {
  description = "Version of the ArgoCD Helm chart."
  type        = string
}

variable "repository_url" {
  description = "Git repository containing the Kubernetes manifests."
  type        = string
}

variable "target_revision" {
  description = "Git revision ArgoCD should track."
  type        = string
}

variable "application_path" {
  description = "Path containing the Kubernetes application manifests."
  type        = string
}