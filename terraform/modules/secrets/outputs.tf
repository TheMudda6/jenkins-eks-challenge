# -----------------------------------------------------------------------------
#
# Secrets Module Outputs
#
# Purpose:
# Exposes the PostgreSQL secret name and ARN for use by dependent
# Terraform modules and Kubernetes secret integration.
#
# -----------------------------------------------------------------------------

output "postgres_secret_name" {
  value = aws_secretsmanager_secret.postgres.name
}

output "postgres_secret_arn" {
  value = aws_secretsmanager_secret.postgres.arn
}

output "grafana_secret_arn" {
  description = "ARN of the Grafana secret stored in AWS Secrets Manager."
  value       = aws_secretsmanager_secret.grafana.arn
}