# -----------------------------------------------------------------------------
# Terraform Backend
#
# Purpose:
# Stores Terraform state remotely in Amazon S3 so infrastructure state is
# shared, durable and protected from accidental local deletion.
#
# Locking:
# Prevents multiple Terraform operations from modifying the same state
# simultaneously.
# -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket       = "mudassir-tf-state-893061519920"
    key          = "jenkins/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}