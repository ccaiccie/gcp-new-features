variable "project_id" {
  description = "Lab project ID. Use a test project: this lab changes who can edit firewall rules in it."
  type        = string
}

variable "region" {
  description = "Default region for the provider."
  type        = string
  default     = "us-central1"
}

variable "tester_member" {
  description = "The account that runs the test scripts, in IAM member format, for example user:you@example.com. It gets Service Account Token Creator on the two lab service accounts so it can impersonate them."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource IDs."
  type        = string
  default     = "uap"
}
