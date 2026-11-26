variable "project_id" {
  description = "Your Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the regional internal Application Load Balancer."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the backend and client VMs."
  type        = string
  default     = "us-central1-a"
}

variable "prefix" {
  description = "Name prefix for lab resources."
  type        = string
  default     = "authz-lab"
}
