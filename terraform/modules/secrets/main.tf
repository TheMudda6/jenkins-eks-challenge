resource "aws_secretsmanager_secret" "postgres" {
  name = "jenkins/postgres"

  recovery_window_in_days = 0

  tags = {
    Name        = "postgres-secret"
    Project     = "jenkins-eks"
    Environment = "dev"
  }
}


resource "aws_secretsmanager_secret_version" "postgres" {

  secret_id = aws_secretsmanager_secret.postgres.id

  secret_string = jsonencode({
    POSTGRES_DB       = "orders"
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = var.postgres_password
  })
}