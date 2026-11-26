variable "project_id" {
  description = "Your Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the lab backend VM and subnet."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone for the lab backend VM."
  type        = string
  default     = "us-central1-a"
}

variable "prefix" {
  description = "Short prefix for lab resource names."
  type        = string
  default     = "armor-cel-lab"
}
