variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Region for the Autopilot cluster (a regional location)."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for cluster and membership names."
  default     = "csm-lab"
}

variable "create_cluster" {
  type        = bool
  description = "Create a GKE Autopilot cluster, register it to the fleet, and enable managed Cloud Service Mesh. Set false to enable only the project-level servicemesh fleet feature."
  default     = true
}
