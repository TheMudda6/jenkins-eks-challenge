# -----------------------------------------------------------------------------
# Cloudflare Jenkins DNS
#
# Purpose:
# Creates the public Jenkins CNAME pointing at the AWS Application Load
# Balancer created by the Kubernetes Ingress.
#
# The ALB hostname is supplied dynamically by deploy.sh after the Ingress
# becomes ready.
# -----------------------------------------------------------------------------

data "cloudflare_zone" "main" {
  filter = {
    name = var.cloudflare_zone_name
  }
}

resource "cloudflare_dns_record" "jenkins" {
  zone_id = data.cloudflare_zone.main.id
  name    = var.jenkins_hostname
  type    = "CNAME"
  content = var.alb_hostname
  ttl     = 300
  proxied = false
}
