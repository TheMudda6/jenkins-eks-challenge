resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

  values = [
    yamlencode({
      extraObjects = [
        {
          apiVersion = "argoproj.io/v1alpha1"
          kind       = "Application"

          metadata = {
            name      = "jenkins-application"
            namespace = var.namespace
          }

          spec = {
            project = "default"

            source = {
              repoURL        = var.repository_url
              targetRevision = var.target_revision
              path           = var.application_path
            }

            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "jenkins"
            }

            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }

              syncOptions = [
                "CreateNamespace=true"
              ]
            }
          }
        }
      ]
    })
  ]
}