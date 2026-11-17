variable "project_id" {
  type        = string
  description = "Project that will hold the lab."
}

variable "region" {
  type        = string
  description = "Region for the Cloud Storage backend bucket."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "pq-tls"
}

variable "ssl_policy_mode" {
  type        = string
  description = "Which SSL policy to attach to the target HTTPS proxy: default (Phase 2 behavior, post-quantum key exchange allowed) or deferred (disallow X25519MLKEM768 until October 2027)."
  default     = "default"

  validation {
    condition     = contains(["default", "deferred"], var.ssl_policy_mode)
    error_message = "ssl_policy_mode must be default or deferred."
  }
}

variable "create_load_balancer" {
  type        = bool
  description = "Create the global external Application Load Balancer, reserved IP, and self-signed certificate. The two SSL policies are always created. Set false if you only want the policies."
  default     = true
}
