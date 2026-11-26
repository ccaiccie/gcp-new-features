variable "project_id" {
  description = "Google Cloud project ID where the VPC, Cloud NAT, VM, and firewall policy are created."
  type        = string
}

variable "organization_id" {
  description = "Numeric Google Cloud organization ID if using organization-level NGFW resources. Leave null to use project-level scope."
  type        = string
  default     = null
}

variable "use_project_scope" {
  description = "When true, creates project-level security profile, profile group, and firewall endpoint. Set false to use organization-level scope."
  type        = bool
  default     = true
}

variable "region" {
  description = "Google Cloud region for the subnet, Cloud Router, and Cloud NAT."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the private test VM and the zonal Cloud NGFW firewall endpoint."
  type        = string
  default     = "us-central1-a"
}

variable "prefix" {
  description = "Short lowercase prefix for lab resource names."
  type        = string
  default     = "urlf-lab"
}

variable "allowed_domains" {
  description = "Domain and SNI matcher strings explicitly allowed by priority 1000."
  type        = list(string)
  default     = ["*example.com"]
}

variable "denied_domains" {
  description = "Domain and SNI matcher strings explicitly denied by priority 500."
  type        = list(string)
  default     = ["*example.org"]
}
