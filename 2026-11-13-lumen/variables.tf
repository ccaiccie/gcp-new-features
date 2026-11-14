variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Region for the Cloud Router and Partner Interconnect attachment. The Lumen last-mile preview was announced in us-east4."
  default     = "us-east4"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "lumen-lab"
}

variable "subnet_cidr" {
  type        = string
  description = "Primary IPv4 range for the sample subnet."
  default     = "10.20.0.0/24"
}

variable "cloud_router_asn" {
  type        = number
  description = "Private BGP ASN for the Cloud Router."
  default     = 64512
}

variable "edge_availability_domain" {
  type        = string
  description = "Partner attachment availability domain. Valid values are AVAILABILITY_DOMAIN_1 or AVAILABILITY_DOMAIN_2."
  default     = "AVAILABILITY_DOMAIN_1"
}

variable "mtu" {
  type        = number
  description = "Attachment MTU. 1500 or 2100 are typical values."
  default     = 1500
}
