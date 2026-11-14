variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Region for the regional external proxy Network Load Balancer. SNI-based routing is documented for this regional external type."
  default     = "us-east4"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "sni-ipv6-lab"
}

variable "subnet_cidr" {
  type        = string
  description = "IPv4 range of the dual-stack frontend subnet that supplies the IPv6 /96 for the IPv6 forwarding rule."
  default     = "10.30.0.0/24"
}

variable "proxy_only_cidr" {
  type        = string
  description = "IPv4 range of the regional proxy-only subnet. Must not overlap other subnets in the VPC."
  default     = "10.30.128.0/23"
}

variable "app_sni_host" {
  type        = string
  description = "SNI hostname that selects the app backend service."
  default     = "app.example.com"
}

variable "api_sni_host" {
  type        = string
  description = "SNI hostname that selects the api backend service."
  default     = "api.example.com"
}
