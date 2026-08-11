resource "aws_ecr_repository" "application" {
  name = "${var.project_name}-${var.environment}-application"

  image_tag_mutability = "MUTABLE"

  force_delete = true
}