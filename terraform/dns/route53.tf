# -----------------------------------------------------------------------------
#
# Route 53 Jenkins DNS
#
# Purpose:
# Creates a dedicated public Route 53 hosted zone for the Jenkins subdomain.
#
# Cloudflare remains authoritative for mud-as-sir.uk. The Jenkins subdomain
# will be delegated from Cloudflare to this Route 53 hosted zone so that
# ExternalDNS and cert-manager can manage Jenkins DNS records independently.
#
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "jenkins" {
  name = var.jenkins_zone_name

  tags = {
    Name        = "jenkins-${var.environment}-dns"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "jenkins_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the Jenkins subdomain."
  value       = aws_route53_zone.jenkins.zone_id
}

output "jenkins_name_servers" {
  description = "Route 53 name servers for the Jenkins subdomain delegation."
  value       = aws_route53_zone.jenkins.name_servers
}
