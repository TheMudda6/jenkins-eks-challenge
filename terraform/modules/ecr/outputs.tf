# -----------------------------------------------------------------------------
#
# ECR Module Outputs
#
# Purpose:
# Exposes the ECR repository URL, name and ARN for use by other
# Terraform modules and deployment workflows.
#
# -----------------------------------------------------------------------------

output "repository_url" {
  value = aws_ecr_repository.application.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.application.name
}

output "repository_arn" {
  value = aws_ecr_repository.application.arn
}