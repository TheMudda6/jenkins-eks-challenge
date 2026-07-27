output "hostname" {
  value = cloudflare_dns_record.service.name
}