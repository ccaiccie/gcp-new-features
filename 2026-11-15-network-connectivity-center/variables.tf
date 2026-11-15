variable "project_id" {
  description = "Project where the lab hub, VPC spokes, and sample VMs are created."
  type        = string
}

variable "region" {
  description = "Region for subnets and sample VMs."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the sample VMs."
  type        = string
  default     = "us-central1-a"
}

variable "hub_name" {
  description = "Name of the Network Connectivity Center hub."
  type        = string
  default     = "ncc-lab-hub"
}

variable "network_prefix" {
  description = "Prefix for VPC, subnet, spoke, and VM names."
  type        = string
  default     = "ncc-lab"
}

variable "center_cidr" {
  description = "Primary range for the center subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "edge_a_cidr" {
  description = "Primary range for edge A subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "edge_b_cidr" {
  description = "Primary range for edge B subnet."
  type        = string
  default     = "10.20.1.0/24"
}
