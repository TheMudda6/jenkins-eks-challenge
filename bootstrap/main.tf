resource "aws_s3_bucket" "terraform_state" {
  bucket = "mudassir-tf-state-893061519920"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "mudassir-tf-state-893061519920"
    key    = "jenkins/terraform.tfstate"
    region = "eu-west-2"
  }
}