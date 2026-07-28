#
# Jenkins Persistent Volume Claim
#
# Purpose:
# Requests persistent storage for the Jenkins home directory.
#

resource "kubernetes_persistent_volume_claim_v1" "jenkins" {

  wait_until_bound = false

  metadata {
    name      = "jenkins-pvc"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {

    storage_class_name = "gp3-retain"

    access_modes = [
      "ReadWriteOnce"
    ]

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}