variable "project_id" {
  description = "Disposable Google Cloud project ID for the Network Intelligence Center lab."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the lab subnet and resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the lab VM instance."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix applied to all lab resources."
  type        = string
  default     = "nic-lab"
}

variable "machine_type" {
  description = "Compute Engine machine type for the lab VM."
  type        = string
  default     = "e2-micro"
}
