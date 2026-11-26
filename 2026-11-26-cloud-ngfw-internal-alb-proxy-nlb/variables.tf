variable "project_id" {
  description = "Your Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the VPC subnets, internal load balancers, and regional network firewall policy."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Compute Engine zone within the chosen region."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix applied to lab resources."
  type        = string
  default     = "ngfw-ilb-lab"
}

variable "proxy_only_cidr" {
  description = "CIDR range for the REGIONAL_MANAGED_PROXY subnet (minimum /26, recommended /23)."
  type        = string
  default     = "10.129.0.0/23"
}

variable "backend_subnet_cidr" {
  description = "CIDR range for the backend VM subnet."
  type        = string
  default     = "10.128.10.0/24"
}

variable "client_subnet_cidr" {
  description = "CIDR range for the client test VM subnet."
  type        = string
  default     = "10.128.20.0/24"
}

variable "scope_to_single_forwarding_rule" {
  description = "When true, scope the INTERNAL_MANAGED_LB rules to the single internal ALB forwarding rule via target_forwarding_rules. When false, apply to all internal Envoy LBs in the VPC."
  type        = bool
  default     = true
}

variable "enable_proxy_nlb" {
  description = "Optional: also deploy a Regional Internal Proxy Network Load Balancer on TCP port 8080 sharing the same proxy-only subnet."
  type        = bool
  default     = false
}
