#
# Jenkins Namespace
#
# Purpose:
# Creates the Kubernetes namespace that all Jenkins
# platform resources are deployed into.
#

resource "kubernetes_namespace" "jenkins" {

  metadata {
    name = "jenkins"
  }

}