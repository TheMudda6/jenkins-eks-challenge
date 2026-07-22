terraform {
  backend "s3" {
    bucket       = "mudassir-tf-state-893061519920"
    key          = "jenkins/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}