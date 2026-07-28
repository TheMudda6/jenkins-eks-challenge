#
# Jenkins Ingress
#
# Purpose:
# Exposes the Jenkins service through the AWS Load Balancer Controller.
#
# Creates:
# - Internet-facing Application Load Balancer
# - HTTPS listener
# - HTTP -> HTTPS redirect
# - Routes traffic to Jenkins
# 

resource "kubernetes_ingress_v1" "jenkins" {

  depends_on = [
    kubernetes_namespace.jenkins
  ]

  metadata {
    name      = "jenkins-ingress"
    namespace = kubernetes_namespace.jenkins.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"

      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        {
          HTTP = 80
        },
        {
          HTTPS = 443
        }
      ])

    }
  }

  spec {

    ingress_class_name = "alb"

    rule {

      http {

        path {

          path      = "/"
          path_type = "Prefix"

          backend {

            service {

              name = "jenkins-service"

              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}