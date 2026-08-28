# -----------------------------------------------------------------------------
# Cloudflare DNS Configuration
#
# Purpose:
# Creates the public DNS record used to access Jenkins through the AWS
# Application Load Balancer.
#
# The ALB hostname is supplied after the Kubernetes Ingress is created, allowing
# Terraform to create the Cloudflare CNAME record dynamically.
# -----------------------------------------------------------------------------
data "cloudflare_zone" "main" {
  filter = {
    name = var.cloudflare_zone_name
  }
}

resource "cloudflare_dns_record" "jenkins" {
  count = var.alb_hostname != "" ? 1 : 0

  zone_id = data.cloudflare_zone.main.id
  name    = var.jenkins_hostname
  type    = "CNAME"
  content = var.alb_hostname
  ttl     = 300
  proxied = false
}