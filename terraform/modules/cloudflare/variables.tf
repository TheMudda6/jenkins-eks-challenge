variable "zone_id" {
  description = "Cloudflare Zone ID."
  type        = string
}

variable "hostname" {
  description = "Hostname to create."
  type        = string
}

variable "target_hostname" {
  description = "AWS ALB hostname."
  type        = string
}

variable "proxied" {
  type    = bool
  default = false
}