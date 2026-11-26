variable "access_policy_id" {
  description = "Numeric Access Context Manager policy ID for your disposable test organization."
  type        = string
}

variable "protected_project_id" {
  description = "Disposable test project ID to place inside the service perimeter."
  type        = string
}

variable "protected_project_number" {
  description = "Numeric project number of the disposable protected project (projects/<number>)."
  type        = string
}

variable "external_project_number" {
  description = "Numeric project number of a second disposable project outside the perimeter (for egress rule testing)."
  type        = string
}

variable "operator_identity" {
  description = "Principal allowed by the ingress rule, e.g. user:mike@example.com or serviceAccount:lab-sa@project.iam.gserviceaccount.com."
  type        = string
}

variable "perimeter_name" {
  description = "Perimeter name (max 50 chars, starts with a letter, letters/numbers/underscores only)."
  type        = string
  default     = "lab_vpc_sc_demo_perimeter"
}

variable "enforce_perimeter" {
  description = "Keep false while validating in dry-run mode. Flip to true only after dry-run audit logs are clean."
  type        = bool
  default     = false
}

variable "region" {
  description = "Google Cloud region for the disposable test Cloud Storage bucket."
  type        = string
  default     = "us-central1"
}
