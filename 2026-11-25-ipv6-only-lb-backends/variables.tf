variable "project_id" {
  description = "Google Cloud project ID where the lab resources will be created."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the regional external Application Load Balancer and backends."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Compute Engine zone within the chosen region for the managed instance group."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix applied to all lab resource names."
  type        = string
  default     = "ipv6-lb-lab"
}

variable "proxy_only_subnet_cidr" {
  description = "Primary IPv4 CIDR for the dual-stack (IPV4_IPV6) REGIONAL_MANAGED_PROXY subnet. Google Cloud recommends /23 (minimum /26). The IPv6 ULA range is allocated automatically."
  type        = string
  default     = "10.129.0.0/23"
}

variable "health_check_ipv6_source_ranges" {
  description = "Documented Google Cloud IPv6 health-check probe source ranges to allow in the backend VPC firewall rule. Populate from the official Google Cloud Firewall Rules for Health Checks documentation before applying."
  type        = list(string)
}

variable "machine_type" {
  description = "Compute Engine machine type for the IPv6-only backend VMs."
  type        = string
  default     = "e2-micro"
}
