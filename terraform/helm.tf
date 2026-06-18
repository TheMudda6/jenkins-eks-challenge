resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
  name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value = aws_iam_role.aws_load_balancer_controller.arn
}

 depends_on = [
  module.eks,
  aws_iam_role.aws_load_balancer_controller,
  aws_iam_role_policy_attachment.aws_load_balancer_controller
]
}