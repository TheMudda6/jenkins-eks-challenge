# -----------------------------------------------------------------------------
#
# Amazon ECR Repository
#
# Purpose:
# Creates the Amazon Elastic Container Registry (ECR) repository used to
# store container images for the application.
#
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "application" {
  name = "${var.project_name}-${var.environment}-application"

  image_tag_mutability = "MUTABLE"

  force_delete = true
}