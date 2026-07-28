#
# Jenkins Service
#
# Purpose:
# Exposes the Jenkins Pod internally within the
# Kubernetes cluster. The AWS Load Balancer
# Ingress routes external traffic to this Service.
#

resource "kubernetes_service_v1" "jenkins" {

  metadata {
    name      = "jenkins-service"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    type = "ClusterIP"

    selector = {
      app = "jenkins"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}