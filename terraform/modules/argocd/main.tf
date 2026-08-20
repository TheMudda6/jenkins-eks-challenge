resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

}

resource "helm_release" "jenkins_application" {
  name      = "jenkins-application"
  chart     = "${path.module}/jenkins-application"
  namespace = var.namespace

  depends_on = [
    helm_release.argocd
  ]
}
