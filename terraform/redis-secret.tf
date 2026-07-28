resource "kubernetes_secret_v1" "redis_secret" {

  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  type = "Opaque"

  data = {
    REDIS_PASSWORD = var.redis_password
  }
}