resource "kubernetes_stateful_set_v1" "redis" {

  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    service_name = kubernetes_service_v1.redis.metadata[0].name

    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {

      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {

        container {

          name  = "redis"
          image = "redis:7"

          command = [
            "sh",
            "-c"
          ]

          args = [
            "redis-server --requirepass \"$REDIS_PASSWORD\""
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.redis_secret.metadata[0].name
            }
          }

          volume_mount {
            name       = "redis-storage"
            mount_path = "/data"
          }

          readiness_probe {

            exec {
              command = [
                "redis-cli",
                "ping"
              ]
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }

    volume_claim_template {

      metadata {
        name = "redis-storage"
      }

      spec {

        access_modes = ["ReadWriteOnce"]

        storage_class_name = "gp3-retain"

        resources {
          requests = {
            storage = "20Gi"
          }
        }
      }
    }
  }
}