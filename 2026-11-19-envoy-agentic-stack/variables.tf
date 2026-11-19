variable "project_id" {
  description = "Google Cloud project ID for the lab."
  type        = string
}

variable "region" {
  description = "Region for the subnet and the two stand-in VMs."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the stand-in VMs (must be in var.region)."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "envoy-lab"
}

variable "subnet_cidr" {
  description = "Lab subnet for the two stand-in backends. This range is a lab example, not from the Google Cloud post."
  type        = string
  default     = "10.19.0.0/24"
}

variable "model_ip" {
  description = "Internal address of the model stand-in VM, inside subnet_cidr."
  type        = string
  default     = "10.19.0.10"
}

variable "mcp_ip" {
  description = "Internal address of the MCP stand-in VM, inside subnet_cidr."
  type        = string
  default     = "10.19.0.20"
}

variable "rate_limit_count" {
  description = "Cloud Armor request-count threshold. This is requests, not tokens."
  type        = number
  default     = 10
}

variable "rate_limit_interval_sec" {
  description = "Interval, in seconds, for the Cloud Armor request-count threshold."
  type        = number
  default     = 60
}
