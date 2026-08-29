variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used by Karpenter."
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL of the EKS OIDC issuer used by Karpenter."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where Karpenter is installed."
  type        = string
}

variable "chart_version" {
  description = "Karpenter Helm chart version."
  type        = string
}