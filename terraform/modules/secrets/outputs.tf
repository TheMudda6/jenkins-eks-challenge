output "postgres_secret_name" {
  value = aws_secretsmanager_secret.postgres.name
}

output "postgres_secret_arn" {
  value = aws_secretsmanager_secret.postgres.arn
}