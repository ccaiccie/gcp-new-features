variable "project_id" {
  description = "Google Cloud project ID for the lab."
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet."
  type        = string
  default     = "us-central1"
}

variable "cluster_location" {
  description = "Zone for the lab cluster (zonal keeps it small). Must be in var.region."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "dpv2"
}

variable "release_channel" {
  description = "GKE release channel. In-place migration needs control plane 1.35.3-gke.1155000+ and node pools 1.35.1-gke.1516000+."
  type        = string
  default     = "REGULAR"
}

variable "node_count" {
  description = "Nodes in the lab node pool. Two nodes make the rolling replacement easy to watch."
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Node machine type."
  type        = string
  default     = "e2-standard-2"
}

variable "pods_cidr" {
  description = "Secondary range for Pods. At 110 max Pods per node each node takes a /24, so a /21 holds 8 nodes: the 2 lab nodes plus surge headroom."
  type        = string
  default     = "10.20.0.0/21"
}

variable "services_cidr" {
  description = "Secondary range for ClusterIP Services."
  type        = string
  default     = "10.30.0.0/24"
}

variable "nodes_cidr" {
  description = "Primary subnet range for nodes."
  type        = string
  default     = "10.10.0.0/24"
}

variable "enable_maintenance_window" {
  description = "Add a recurring weekend maintenance window. The migration respects windows and exclusions, so leave this false for a quick lab run."
  type        = bool
  default     = false
}
