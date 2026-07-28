#
# PostgreSQL Secret
#
# Purpose:
# Stores the PostgreSQL credentials used by the
# PostgreSQL StatefulSet.
#

resource "kubernetes_secret_v1" "postgres_secret" {

  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  type = "Opaque"

  data = {
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = "orders"
  }
}