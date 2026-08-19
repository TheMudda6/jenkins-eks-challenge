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
            name      = "root"
            namespace = var.namespace
          }

          spec = {
            project = "default"

            source = {
              repoURL        = "https://github.com/TheMudda6/jenkins-eks-challenge.git"
              targetRevision = "main"
              path           = "kubernetes/applications"
            }

            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = var.namespace
            }

            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }
            }
          }
        }
      ]
    })
  ]

}