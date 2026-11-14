variable "host_project_id" {
  description = "Project ID of the Shared VPC host project."
  type        = string
}

variable "service_project_id" {
  description = "Project ID of the service project that will attach to the host."
  type        = string
}

variable "region" {
  description = "Region for the shared subnet and related resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the sample VM in the service project."
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "Name of the Shared VPC network created in the host project."
  type        = string
  default     = "shared-vpc"
}

variable "subnet_name" {
  description = "Name of the shared subnet."
  type        = string
  default     = "tier-1"
}

variable "subnet_cidr" {
  description = "Primary IPv4 range of the shared subnet, used by the sample VM."
  type        = string
  default     = "10.0.1.0/24"
}

variable "pods_secondary_cidr" {
  description = "Secondary IPv4 range reserved for GKE Pods."
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_secondary_cidr" {
  description = "Secondary IPv4 range reserved for GKE Services."
  type        = string
  default     = "10.0.32.0/20"
}

variable "network_user_members" {
  description = "Additional IAM members to grant roles/compute.networkUser on the shared subnet, for example user:you@example.com. The service project's Google APIs and default Compute service accounts are granted automatically."
  type        = list(string)
  default     = []
}

variable "instance_name" {
  description = "Name of the sample VM created in the service project."
  type        = string
  default     = "svc-vm-1"
}

variable "machine_type" {
  description = "Machine type for the sample VM."
  type        = string
  default     = "e2-micro"
}
