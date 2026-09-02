# -----------------------------------------------------------------------------
# Kubernetes Helm Releases
#
# Purpose:
# Installs Kubernetes infrastructure components required by the platform
# through Helm after the EKS cluster has been provisioned.
#
# This includes the AWS Load Balancer Controller and External Secrets Operator.
# -----------------------------------------------------------------------------

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
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "replicaCount"
    value = "1"
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
    value = module.iam.aws_load_balancer_controller_role_arn
  }

  depends_on = [
    module.eks,
    module.iam,
  ]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  depends_on = [
    module.eks
  ]

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}


# -----------------------------------------------------------------------------
# cert-manager
#
# Purpose:
# Installs cert-manager for automated TLS certificate issuance and renewal.
# Route 53 DNS-01 authentication is provided through the dedicated IRSA role.
# -----------------------------------------------------------------------------

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts"
  chart            = "cert-manager"
  version          = "v1.21.1"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.cert_manager_role_arn
  }

  depends_on = [
    module.eks,
    module.iam,
  ]
}

# -----------------------------------------------------------------------------
# ExternalDNS
#
# Purpose:
# Publishes Kubernetes ingress/service DNS records into the delegated
# Route 53 Jenkins hosted zone using IRSA.
# -----------------------------------------------------------------------------

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.21.1"
  namespace        = "external-dns"
  create_namespace = true

  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.external_dns_role_arn
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  set {
    name  = "domainFilters[0]"
    value = "jenkins.mud-as-sir.uk"
  }

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "registry"
    value = "txt"
  }

  set {
    name  = "txtOwnerId"
    value = "jenkins-eks"
  }

  set {
    name  = "sources[0]"
    value = "service"
  }

  set {
    name  = "sources[1]"
    value = "ingress"
  }

  depends_on = [
    module.eks,
    module.iam,
  ]
}


# -----------------------------------------------------------------------------
# Traefik
#
# Purpose:
# Provides the Kubernetes Ingress controller for HTTP/HTTPS application
# routing. Its LoadBalancer Service is provisioned as an internet-facing
# AWS Network Load Balancer by the AWS Load Balancer Controller.
# -----------------------------------------------------------------------------

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "37.1.0"
  namespace        = "traefik"
  create_namespace = true

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.spec.loadBalancerClass"
    value = "service.k8s.aws/nlb"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ip-address-type"
    value = "ipv4"
  }

  set {
    name  = "ports.web.port"
    value = "80"
  }

  set {
    name  = "ports.websecure.port"
    value = "443"
  }

  set {
    name  = "ports.web.expose.default"
    value = "true"
  }

  set {
    name  = "ports.websecure.expose.default"
    value = "true"
  }

  set {
    name  = "ports.websecure.tls.enabled"
    value = "true"
  }

  set {
    name  = "ingressRoute.dashboard.enabled"
    value = "false"
  }

  set {
    name  = "additionalArguments[0]"
    value = "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  }

  set {
    name  = "additionalArguments[1]"
    value = "--entrypoints.web.http.redirections.entrypoint.scheme=https"
  }

  depends_on = [
    module.eks,
    module.iam,
    helm_release.aws_load_balancer_controller,
  ]
}
