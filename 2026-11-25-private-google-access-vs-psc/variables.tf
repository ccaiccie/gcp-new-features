variable "project_id" {
  description = "Your Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region for subnets and VM."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the private test VM."
  type        = string
  default     = "us-central1-a"
}

variable "vpc_name" {
  description = "Custom-mode VPC name."
  type        = string
  default     = "pga-psc-lab-vpc"
}

variable "psc_endpoint_name" {
  description = "Name for the global PSC forwarding rule (lowercase letters and digits only, max 20 chars)."
  type        = string
  default     = "labpsc"
}

variable "psc_endpoint_ip" {
  description = "Global internal IPv4 address for the PSC endpoint (must be outside all VPC subnet ranges)."
  type        = string
  default     = "10.50.250.5"
}

variable "psc_api_bundle" {
  description = "Google APIs bundle target for the PSC endpoint: all-apis or vpc-sc."
  type        = string
  default     = "all-apis"

  validation {
    condition     = contains(["all-apis", "vpc-sc"], var.psc_api_bundle)
    error_message = "psc_api_bundle must be either 'all-apis' or 'vpc-sc'."
  }
}
