# -----------------------------------------------------------------------------
#
# ArgoCD Module Outputs
#
# Purpose:
# Exposes the ArgoCD namespace and Helm release name for use by other
# Terraform resources and deployment scripts.
#
# -----------------------------------------------------------------------------

output "namespace" {
  value = helm_release.argocd.namespace
}

output "release_name" {
  value = helm_release.argocd.name
}