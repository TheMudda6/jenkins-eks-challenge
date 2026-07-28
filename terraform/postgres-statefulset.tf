#
# PostgreSQL StatefulSet
#
# Purpose:
# Deploys PostgreSQL as a StatefulSet with persistent
# storage. Each replica receives its own stable identity
# and dedicated PersistentVolume.
#

resource "kubernetes_stateful_set_v1" "postgres" {

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    service_name = kubernetes_service_v1.postgres.metadata[0].name

    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {

      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {

        security_context {
          fs_group = 999
        }

        container {

          name  = "postgres"
          image = "postgres:17.6"

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres_secret.metadata[0].name
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {

      metadata {
        name = "postgres-storage"
      }

      spec {

        access_modes = [
          "ReadWriteOnce"
        ]

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