variable "project_id" {
  type        = string
  description = "Project for the lab. The Apigee organization takes the same name as the project ID."
}

variable "region" {
  type        = string
  description = "Region for the Apigee runtime instance, the lab subnet and the PSC NEG. Check the Apigee locations page for supported runtime regions."
  default     = "us-central1"
}

variable "analytics_region" {
  type        = string
  description = "Apigee analytics hosting region. Cannot be changed after the organization is created."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "apigee-lab"
}

variable "billing_type" {
  type        = string
  description = "Apigee organization billing type. EVALUATION is the free 60-day eval org: one instance, two environments, no SLA, deleted by Google after 60 days."
  default     = "EVALUATION"

  validation {
    condition     = contains(["EVALUATION", "PAYG", "SUBSCRIPTION"], var.billing_type)
    error_message = "billing_type must be EVALUATION, PAYG or SUBSCRIPTION."
  }
}

variable "networking_mode" {
  type        = string
  description = "\"psc\" provisions Apigee without VPC peering (Private Service Connect northbound and southbound). \"peering\" reserves a range with service networking and peers your VPC with the Apigee network."
  default     = "psc"

  validation {
    condition     = contains(["psc", "peering"], var.networking_mode)
    error_message = "networking_mode must be \"psc\" or \"peering\"."
  }
}

variable "subnet_cidr" {
  type        = string
  description = "Lab subnet range (used by the PSC NEG and any test VM)."
  default     = "10.10.0.0/24"
}

variable "peering_range_address" {
  type        = string
  description = "Start of the range reserved for Apigee in peering mode. Must not overlap anything else in the VPC."
  default     = "10.200.0.0"
}

variable "peering_range_prefix" {
  type        = number
  description = "Prefix length of the range reserved for Apigee in peering mode. Each instance needs a /22 (eval) or a /22 plus a /28 (paid)."
  default     = 21
}

variable "environments" {
  type        = list(string)
  description = "Apigee environments to create. An eval org allows two."
  default     = ["dev", "prod"]
}

variable "hostname" {
  type        = string
  description = "Hostname for the environment group. Leave empty to use <load balancer IP>.nip.io (testing only)."
  default     = ""
}

variable "create_northbound_lb" {
  type        = bool
  description = "Create a global external Application Load Balancer with a PSC NEG that points at the Apigee instance service attachment (northbound)."
  default     = true
}

variable "backend_service_attachment" {
  type        = string
  description = "Optional southbound target: the self link or ID of a PSC service attachment you already published in front of a backend. When set, the lab creates an Apigee endpoint attachment to it."
  default     = ""
}
