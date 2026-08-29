variable "cloudflare_api_token" {
  description = "Cloudflare API token used for DNS management."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone name."
  type        = string
}

variable "jenkins_hostname" {
  description = "Hostname used to access Jenkins."
  type        = string
}

variable "alb_hostname" {
  description = "AWS ALB hostname created by the Jenkins Kubernetes Ingress."
  type        = string

  validation {
    condition     = trimspace(var.alb_hostname) != ""
    error_message = "alb_hostname must not be empty."
  }
}
