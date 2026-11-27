variable "project_id" {
  description = "Google Cloud project ID where Certificate Manager and Application Load Balancer resources are created."
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for the provider."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Short lowercase prefix for naming lab resources."
  type        = string
  default     = "cm-lab"
}

variable "domain_name" {
  description = "Fully qualified domain name (FQDN) you own (for example, app.example.com). Do not include a trailing dot."
  type        = string
}

variable "dns_authorization_type" {
  description = "DNS authorization type: FIXED_RECORD (default) or PER_PROJECT_RECORD (Google Trust Services only)."
  type        = string
  default     = "FIXED_RECORD"

  validation {
    condition     = contains(["FIXED_RECORD", "PER_PROJECT_RECORD"], var.dns_authorization_type)
    error_message = "dns_authorization_type must be FIXED_RECORD or PER_PROJECT_RECORD."
  }
}

variable "create_cloud_dns_record" {
  description = "Set to true if your domain is hosted in an existing Cloud DNS managed zone in this project and you want Terraform to create the CNAME validation record."
  type        = bool
  default     = false
}

variable "cloud_dns_managed_zone" {
  description = "Name of the existing Cloud DNS public managed zone (required only when create_cloud_dns_record is true)."
  type        = string
  default     = ""
}
