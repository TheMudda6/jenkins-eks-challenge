# Secrets for Postgres Database

resource "kubernetes_secret_v1" "postgres" {

  metadata {
    name      = "postgres-secret"
    namespace = var.namespace
  }

  data = {
    POSTGRES_DB       = var.postgres_db
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
  }

  type = "Opaque"
}