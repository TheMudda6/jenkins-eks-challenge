# -----------------------------------------------------------------------------
#
# Amazon ECR Repositories
#
# Purpose:
# Creates one Amazon ECR repository for each application service.
#
# -----------------------------------------------------------------------------

locals {
  services = toset([
    "api-gateway",
    "order-service",
    "inventory-service",
    "payment-service",
    "notification-service",
    "shipping-service",
    "dashboard-api",
    "scheduler",
    "worker",
  ])
}

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
