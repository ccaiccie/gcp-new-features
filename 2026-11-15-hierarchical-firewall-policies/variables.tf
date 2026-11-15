variable "folder_id" {
  type        = string
  description = "Numeric folder ID that parents and is associated with the hierarchical policy. Applying the lab requires this folder and the Compute Security Admin role on it."
}

variable "project_id" {
  type        = string
  description = "Optional project used only by the provider. Hierarchical policies themselves are folder resources and do not live in a project."
  default     = ""
}

variable "region" {
  type        = string
  description = "Provider default region. Not used by the policy resources."
  default     = "us-central1"
}

variable "policy_short_name" {
  type        = string
  description = "Short name for the hierarchical firewall policy. Must be unique within the organization."
  default     = "lab-ssh-baseline"
}
