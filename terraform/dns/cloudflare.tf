# -----------------------------------------------------------------------------
#
# Cloudflare DNS Delegation
#
# Purpose:
# Delegates jenkins.mud-as-sir.uk from Cloudflare to the dedicated Route 53
# hosted zone managed by this Terraform stack.
#
# -----------------------------------------------------------------------------

data "cloudflare_zone" "root" {
  filter = {
    name = "mud-as-sir.uk"
  }
}

resource "cloudflare_dns_record" "jenkins_delegation" {
  for_each = toset(aws_route53_zone.jenkins.name_servers)

  zone_id = data.cloudflare_zone.root.id
  name    = "jenkins.mud-as-sir.uk"
  type    = "NS"
  ttl     = 1
  content = each.value
}