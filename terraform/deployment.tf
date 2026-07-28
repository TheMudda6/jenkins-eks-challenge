#
# Jenkins Deployment
#
# Purpose:
# Deploys the Jenkins controller into the Kubernetes cluster.
# Mounts persistent storage so Jenkins configuration and jobs
# survive Pod restarts.
#

resource "kubernetes_deployment_v1" "jenkins" {

  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    replicas = 1

    selector {
      match_labels = {
        app = "jenkins"
      }
    }

    template {

      metadata {
        labels = {
          app = "jenkins"
        }
      }

      spec {

        security_context {
          fs_group = 1000
        }

        container {

          name  = "jenkins"
          image = "jenkins/jenkins:2.516.1-lts-jdk21"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "jenkins-storage"
            mount_path = "/var/jenkins_home"
          }
        }

        volume {

          name = "jenkins-storage"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.jenkins.metadata[0].name
          }
        }
      }
    }
  }
}