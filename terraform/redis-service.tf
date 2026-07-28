resource "kubernetes_service_v1" "redis" {

  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    cluster_ip = "None"

    selector = {
      app = "redis"
    }

    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
    }
  }
}