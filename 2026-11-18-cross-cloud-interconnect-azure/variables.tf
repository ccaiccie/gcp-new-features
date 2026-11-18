variable "project_id" {
  type        = string
  description = "Project for the lab."
}

variable "region" {
  type        = string
  description = "Google Cloud region for the transport. Azure preview regions: us-east4, us-west2, europe-west3."
  default     = "us-east4"

  validation {
    condition     = contains(["us-east4", "us-west2", "europe-west3"], var.region)
    error_message = "Partner Cross-Cloud Interconnect for Azure (preview) is offered in us-east4, us-west2 and europe-west3."
  }
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "pcci-az"
}

variable "subnet_cidr" {
  type        = string
  description = "Google Cloud subnet range. Must not overlap the Azure VNet address space."
  default     = "10.20.0.0/24"
}

variable "azure_vnet_cidr" {
  type        = string
  description = "Address space of the Azure VNet you connect to. Allowed in by the test firewall rule."
  default     = "10.30.0.0/16"
}

variable "connection_mode" {
  type        = string
  description = "How the transport connects to Google Cloud: \"peering\" (VPC Network Peering to the lab VPC) or \"ncc\" (a Network Connectivity Center hub)."
  default     = "peering"

  validation {
    condition     = contains(["peering", "ncc"], var.connection_mode)
    error_message = "connection_mode must be \"peering\" or \"ncc\"."
  }
}

variable "create_transport" {
  type        = bool
  description = "Create the partner Cross-Cloud Interconnect transport. Leave false until you have an Azure account and a remote profile name."
  default     = false
}

variable "remote_profile_name" {
  type        = string
  description = "Azure remote transport profile for the region. Find it with: gcloud network-connectivity transports remote-profiles list --region REGION"
  default     = ""
}

variable "remote_account_id" {
  type        = string
  description = "ID of your Azure account, as requested when you create the transport."
  default     = ""
}

variable "bandwidth" {
  type        = string
  description = "Transport bandwidth. Must be supported by the remote profile. During the Azure preview, the docs list only 1 Gbps (BPS_1G) as available, free of charge."
  default     = "BPS_1G"
}

variable "advertised_routes" {
  type        = list(string)
  description = "Extra prefixes advertised to Azure in addition to the routes Google Cloud already exchanges."
  default     = []
}
