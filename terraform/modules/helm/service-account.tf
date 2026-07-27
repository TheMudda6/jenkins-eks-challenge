# -
# AWS Load Balancer Controller Service Account
# -
# Creates the Kubernetes service account used by the AWS Load Balancer
# Controller. The IRSA annotation links this service account to the IAM
# role created by the IAM module, allowing the controller to securely
# access AWS APIs without long-lived credentials.
# -

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = var.aws_load_balancer_controller_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_role_arn
    }
  }
}