#
# PostgreSQL Headless Service
#
# Purpose:
# Provides stable network identities for the PostgreSQL
# StatefulSet Pods. Each Pod receives its own DNS name,
# allowing Kubernetes to consistently identify replicas.
#

resource "kubernetes_service_v1" "postgres" {

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    cluster_ip = "None"

    selector = {
      app = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }
}