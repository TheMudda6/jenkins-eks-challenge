# Helm release for AWS ALB Ingress Controller

resource "helm_release" "aws_alb_ingress_controller" {
  name       = "aws-alb-ingress-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-alb-ingress-controller"
  namespace  = var.namespace
  version    = var.alb_ingress_controller_version

# Cluster name is required for the AWS ALB Ingress Controller to function properly.
# It is used to identify the cluster in AWS and to create the necessary resources for the controller to operate.

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

# Automatically discover the AWS Region so the controller
# can create and manage AWS resources without hardcoding
# a specific region.


  set {
    name  = "autoDiscoverAwsRegion"
    value = "true"
  }

# The AWS ALB Ingress Controller requires the AWS VPC ID to be specified in order to function properly. 
# This is used to identify the VPC in which the cluster is running and to create the necessary resources for the controller to operate.  

  set {
    name  = "autoDiscoverAwsVpcID"
    value = "true"
  }


# The AWS ALB Ingress Controller requires an IAM role to be associated with the service account that it runs under.
# This role allows the controller to create and manage AWS resources on behalf of the cluster.

set {
  name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value = var.aws_load_balancer_controller_role_arn
}

}