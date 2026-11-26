variable "project_id" {
  description = "Google Cloud project ID where the two-VPC HA VPN lab will be deployed."
  type        = string
}

variable "region" {
  description = "Google Cloud region for both HA VPN gateways and Cloud Routers."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefix applied to all lab resources."
  type        = string
  default     = "nt-havpn"
}

variable "shared_secret" {
  description = "IPsec IKEv2 pre-shared key for the HA VPN tunnels. Supply via terraform.tfvars (never commit)."
  type        = string
  sensitive   = true
}

variable "router_a_asn" {
  description = "Private BGP ASN for Cloud Router A (64512-65534 or 4200000000-4294967294)."
  type        = number
  default     = 65001
}

variable "router_b_asn" {
  description = "Private BGP ASN for Cloud Router B (64512-65534 or 4200000000-4294967294)."
  type        = number
  default     = 65002
}

variable "tunnel0_base_priority" {
  description = "Base advertised route priority (BGP MED, 0-65535, default 100, recommended 0-200) for Tunnel 0."
  type        = number
  default     = 100
}

variable "tunnel1_base_priority" {
  description = "Base advertised route priority (BGP MED, 0-65535, default 100, recommended 0-200) for Tunnel 1. Set higher than tunnel0_base_priority (e.g., 150) for active-passive preference."
  type        = number
  default     = 100
}

variable "custom_prefix_a" {
  description = "Custom IPv4 CIDR advertised by Cloud Router A in addition to VPC A subnets."
  type        = string
  default     = "10.10.250.0/24"
}

variable "custom_prefix_b" {
  description = "Custom IPv4 CIDR advertised by Cloud Router B in addition to VPC B subnets."
  type        = string
  default     = "10.20.250.0/24"
}
