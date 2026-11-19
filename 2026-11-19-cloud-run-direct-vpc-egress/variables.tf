variable "project_id" {
  description = "Google Cloud project ID for the lab."
  type        = string
}

variable "region" {
  description = "Region for the subnet, Cloud NAT, backend VM and Cloud Run job."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the backend VM (must be in var.region)."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "dvpc"
}

variable "run_subnet_cidr" {
  description = "Subnet used by Direct VPC egress. Cloud Run needs a /26 or larger and uses about 2 IPs per instance."
  type        = string
  default     = "10.10.0.0/26"

  validation {
    condition     = tonumber(split("/", var.run_subnet_cidr)[1]) <= 26
    error_message = "Direct VPC egress needs a /26 or larger subnet."
  }
}

variable "backend_ip" {
  description = "Static internal IP of the backend VM, inside run_subnet_cidr."
  type        = string
  default     = "10.10.0.10"
}

variable "network_tag" {
  description = "Network tag set on the Cloud Run revision/execution; egress firewall rules target it."
  type        = string
  default     = "run-egress"
}

variable "vpc_egress" {
  description = "Cloud Run egress setting: ALL_TRAFFIC (internet goes through Cloud NAT) or PRIVATE_RANGES_ONLY."
  type        = string
  default     = "ALL_TRAFFIC"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress)
    error_message = "vpc_egress must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

variable "echo_url" {
  description = "Public URL that returns the caller's public IP, used to prove which source address the internet sees."
  type        = string
  default     = "https://ifconfig.me/ip"
}

variable "create_connector" {
  description = "Also create a Serverless VPC Access connector and a second job that uses it, to compare both paths (adds VM cost)."
  type        = bool
  default     = false
}

variable "connector_cidr" {
  description = "Unused /28 range for the optional Serverless VPC Access connector."
  type        = string
  default     = "10.8.0.0/28"
}
