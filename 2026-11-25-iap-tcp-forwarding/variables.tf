variable "project_id" {
  description = "Google Cloud project ID where the IAP lab will be deployed."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the VPC subnet."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the private Compute Engine VM."
  type        = string
  default     = "us-central1-a"
}

variable "prefix" {
  description = "Short lowercase prefix for resource names."
  type        = string
  default     = "iap-lab"
}

variable "user_member" {
  description = "IAM principal granted IAP HTTPS and IAP Tunnel access (e.g., user:alice@example.com or group:admins@example.com)."
  type        = string
}
