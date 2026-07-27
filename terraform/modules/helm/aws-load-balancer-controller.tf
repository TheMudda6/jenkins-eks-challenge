# Helm release for AWS ALB Ingress Controller

resource "helm_release" "aws_load_balancer_controller" {

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller
  ]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = var.aws_load_balancer_controller_namespace
  version    = var.aws_load_balancer_controller_version

  # Cluster name is required for the AWS ALB Ingress Controller to function properly.
  # It is used to identify the cluster in AWS and to create the necessary resources for the controller to operate.

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  # Service account creation

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  # Service account name

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Associate the existing Kubernetes service account with the IAM role
  # created by the IAM module using IRSA. This allows the controller to
  # securely call AWS APIs without storing long-lived AWS credentials.

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.aws_load_balancer_controller_role_arn
  }

  # Set Region

  set {
    name  = "region"
    value = var.aws_region
  }

  # Set VPC ID

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

}