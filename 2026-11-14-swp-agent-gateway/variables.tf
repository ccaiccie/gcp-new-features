variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Region for Secure Web Proxy and the Agent Gateway. Cloud Run's gated preview was documented in europe-west1 and us-central1."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "swp-agent-lab"
}

variable "subnet_cidr" {
  type        = string
  description = "IPv4 range of the private subnet that hosts the Secure Web Proxy address."
  default     = "10.40.0.0/20"
}

variable "proxy_only_cidr" {
  type        = string
  description = "IPv4 range of the regional proxy-only subnet."
  default     = "192.168.0.0/23"
}

variable "certificate_dns_name" {
  type        = string
  description = "DNS name placed on the lab's self-signed certificate. Not a public certificate."
  default     = "swp.example.internal"
}

variable "allow_host" {
  type        = string
  description = "Hostname allowed by the sample Secure Web Proxy policy rule."
  default     = "example.com"
}

variable "include_registry" {
  type        = bool
  description = "If true, set the Agent Gateway registries list to this project's Agent Registry location. Leave false if you have not enabled Agent Registry."
  default     = false
}
