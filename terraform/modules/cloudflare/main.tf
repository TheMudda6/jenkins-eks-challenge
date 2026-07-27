resource "cloudflare_dns_record" "service" {

  zone_id = var.zone_id

  name = var.hostname

  type = "CNAME"

  content = var.target_hostname

  proxied = var.proxied

  ttl = 1
}