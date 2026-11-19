variable "project_id" {
  description = "Google Cloud project ID for the lab."
  type        = string
}

variable "region" {
  description = "Region for the subnets, Cloud Router and Cloud NAT (NAT64)."
  type        = string
  default     = "us-central1"
}

variable "cluster_location" {
  description = "Zone (cheaper, one control plane zone) or region for the GKE cluster. Must be in var.region."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "v6gke"
}

variable "create_cluster" {
  description = "Create the single-stack IPv6 GKE cluster with gcloud (terraform_data + local-exec). The hashicorp/google provider 8.12.0 has no IPV6 cluster stack type yet. Set false to run the printed gcloud command yourself."
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "GKE version for the cluster. Single-stack IPv6 needs 1.37.1-gke.3020000 or later (Preview)."
  type        = string
  default     = "1.37.1-gke.3020000"
}

variable "machine_type" {
  description = "Node machine type. Preview supports E2, N1, N2, N2D, N4, C3, C3D, C4, C4D, C4A (Axion) and Z3 families, plus Cloud TPU v6e."
  type        = string
  default     = "e2-standard-2"
}

variable "num_nodes" {
  description = "Nodes per zone in the default node pool."
  type        = number
  default     = 1
}

variable "nat_log_filter" {
  description = "Cloud NAT log filter: ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat_log_filter)
    error_message = "nat_log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}

variable "nat44_option" {
  description = "Required NAT44 setting on the NAT gateway. The VPC is IPv6-only, so nothing is translated for IPv4 either way. Use ALL_SUBNETWORKS_ALL_IP_RANGES if the API rejects an empty LIST_OF_SUBNETWORKS."
  type        = string
  default     = "LIST_OF_SUBNETWORKS"

  validation {
    condition     = contains(["LIST_OF_SUBNETWORKS", "ALL_SUBNETWORKS_ALL_IP_RANGES"], var.nat44_option)
    error_message = "nat44_option must be LIST_OF_SUBNETWORKS or ALL_SUBNETWORKS_ALL_IP_RANGES."
  }
}
