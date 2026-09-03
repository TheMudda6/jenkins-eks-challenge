# -----------------------------------------------------------------------------
#
# ECR Module Outputs
#
# Purpose:
# Exposes repository URLs, names and ARNs for all application services.
#
# -----------------------------------------------------------------------------

output "repository_urls" {
  description = "ECR repository URLs keyed by service name."
  value = {
    for service, repository in aws_ecr_repository.services :
    service => repository.repository_url
  }
}

output "repository_names" {
  description = "ECR repository names keyed by service name."
  value = {
    for service, repository in aws_ecr_repository.services :
    service => repository.name
  }
}

output "repository_arns" {
  description = "ECR repository ARNs keyed by service name."
  value = {
    for service, repository in aws_ecr_repository.services :
    service => repository.arn
  }
}
