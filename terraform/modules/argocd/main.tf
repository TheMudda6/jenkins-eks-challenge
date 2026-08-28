# -----------------------------------------------------------------------------
#
# ArgoCD Helm Release
#
# Purpose:
# Installs ArgoCD into the EKS cluster using the official ArgoCD Helm chart.
#
# ArgoCD provides GitOps-based deployment and lifecycle management for the
# Kubernetes resources defined in the project's Git repository.
#
# -----------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

}
