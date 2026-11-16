variable "project_id" {
  type        = string
  description = "Project that will hold the lab."
}

variable "region" {
  type        = string
  description = "Region for the subnet, router and NAT gateway."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zone for the optional test VM."
  default     = "us-central1-a"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "natlab"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary range of the lab subnet."
  default     = "10.70.0.0/24"
}

variable "min_ports_per_vm" {
  type        = number
  description = "Minimum NAT source ports per VM (dynamic port allocation). Default in the product is 32."
  default     = 64
}

variable "max_ports_per_vm" {
  type        = number
  description = "Maximum NAT source ports per VM (dynamic port allocation)."
  default     = 1024
}

variable "tcp_time_wait_timeout_sec" {
  type        = number
  description = "How long Cloud NAT holds a closed TCP mapping before reusing the post-NAT tuple."
  default     = 30
}

variable "nat_log_filter" {
  type        = string
  description = "ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat_log_filter)
    error_message = "nat_log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}

variable "partner_destination_cidr_ip" {
  type        = string
  description = "Destination IP matched by the NAT rule (documentation address by default; replace with your partner's address)."
  default     = "203.0.113.10"
}

variable "create_vm" {
  type        = bool
  description = "Create the test VM and the IAP SSH firewall rule."
  default     = true
}
