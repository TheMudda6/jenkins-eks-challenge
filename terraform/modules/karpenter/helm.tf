# -----------------------------------------------------------------------------
#
# Karpenter CRDs
#
# Purpose:
# Installs the Karpenter Custom Resource Definitions separately from the
# controller chart so their lifecycle can be managed independently.
#
# -----------------------------------------------------------------------------

resource "helm_release" "karpenter_crd" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

  wait = true
}

# -----------------------------------------------------------------------------
#
# Karpenter Controller
#
# Purpose:
# Installs the Karpenter controller into the EKS cluster.
#
# The controller assumes its IAM role through the EKS OIDC provider.
#
# -----------------------------------------------------------------------------

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"

  namespace        = var.namespace
  create_namespace = true

  version = var.chart_version

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.controller.arn
  }

  depends_on = [
    helm_release.karpenter_crd
  ]

  wait = true
}