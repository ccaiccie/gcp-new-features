variable "project_id" {
  description = "Google Cloud project ID for the lab."
  type        = string
}

variable "region" {
  description = "Region for the subnet and backend VM."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the backend VM."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "mtls"
}

variable "machine_type" {
  description = "Machine type for the header-echo backend VM."
  type        = string
  default     = "e2-micro"
}

variable "server_hostname" {
  description = "Hostname in the lab's self-signed server certificate. Tests use curl --resolve, so no DNS record is needed."
  type        = string
  default     = "mtls-lab.example.com"
}

variable "client_validation_mode" {
  description = "ServerTlsPolicy client validation mode: REJECT_INVALID, ALLOW_INVALID_OR_MISSING_CLIENT_CERT or ALLOW_VALIDATION_RELAXATIONS."
  type        = string
  default     = "REJECT_INVALID"
  validation {
    condition     = contains(["REJECT_INVALID", "ALLOW_INVALID_OR_MISSING_CLIENT_CERT", "ALLOW_VALIDATION_RELAXATIONS"], var.client_validation_mode)
    error_message = "Use REJECT_INVALID, ALLOW_INVALID_OR_MISSING_CLIENT_CERT or ALLOW_VALIDATION_RELAXATIONS."
  }
}

variable "client_validation_relaxations" {
  description = "Relaxations used only with ALLOW_VALIDATION_RELAXATIONS: ALLOW_MISSING_EKU, ALLOW_SHA1_HASHING, ALLOW_EXPIRED_LEAF_CERTIFICATE."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for r in var.client_validation_relaxations : contains(["ALLOW_MISSING_EKU", "ALLOW_SHA1_HASHING", "ALLOW_EXPIRED_LEAF_CERTIFICATE"], r)])
    error_message = "Allowed values: ALLOW_MISSING_EKU, ALLOW_SHA1_HASHING, ALLOW_EXPIRED_LEAF_CERTIFICATE."
  }
}
