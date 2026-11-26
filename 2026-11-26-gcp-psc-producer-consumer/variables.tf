variable "producer_project_id" {
  description = "Google Cloud project ID for the PSC service producer (placeholder in example)."
  type        = string
}

variable "consumer_project_id" {
  description = "Google Cloud project ID for the PSC service consumer (placeholder in example)."
  type        = string
}

variable "region" {
  description = "Google Cloud region where both the producer service attachment and consumer endpoint are deployed."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Compute Engine zone inside the chosen region for lab VMs."
  type        = string
  default     = "us-central1-a"
}

variable "connection_preference" {
  description = "Service attachment connection preference: ACCEPT_MANUAL (recommended) or ACCEPT_AUTOMATIC."
  type        = string
  default     = "ACCEPT_MANUAL"

  validation {
    condition     = contains(["ACCEPT_MANUAL", "ACCEPT_AUTOMATIC"], var.connection_preference)
    error_message = "connection_preference must be ACCEPT_MANUAL or ACCEPT_AUTOMATIC."
  }
}

variable "accept_consumer_project" {
  description = "When true and connection_preference is ACCEPT_MANUAL, adds consumer_project_id to consumer_accept_lists. Set to false to demonstrate PENDING status."
  type        = bool
  default     = true
}

variable "reject_consumer_project" {
  description = "When true, adds consumer_project_id to consumer_reject_lists to demonstrate REJECTED status."
  type        = bool
  default     = false
}

variable "consumer_connection_limit" {
  description = "Maximum number of PSC endpoints accepted from the consumer project."
  type        = number
  default     = 2
}

variable "reconcile_connections" {
  description = "When true, changes to accept/reject lists also reconcile existing connections."
  type        = bool
  default     = true
}

variable "enable_proxy_protocol" {
  description = "Enable PROXY protocol v2 on the service attachment (backend app must parse PROXY v2 headers if true)."
  type        = bool
  default     = false
}

variable "service_domain_name" {
  description = "Optional published service DNS domain name with trailing dot (used for automatic consumer DNS if Cloud DNS + Service Directory APIs are enabled)."
  type        = string
  default     = "us-central1.p.example.internal."
}

variable "manual_dns_zone_domain" {
  description = "Private Cloud DNS zone suffix in the consumer VPC for explicit A-record resolution."
  type        = string
  default     = "psc-lab.internal."
}
