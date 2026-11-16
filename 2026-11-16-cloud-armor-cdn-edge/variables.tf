variable "project_id" {
  type        = string
  description = "Project that will hold the lab."
}

variable "region" {
  type        = string
  description = "Region for the Cloud Storage bucket."
  default     = "us-central1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "armor-edge"
}

variable "denied_asn" {
  type        = number
  description = "Placeholder ASN used in the origin.asn deny rule. Replace with an ASN you have investigated. Default 64512 is a documentation placeholder, not a real operator you should block."
  default     = 64512
}

variable "denied_path_prefix" {
  type        = string
  description = "HTTP path prefix denied by the edge policy."
  default     = "/lab-blocked"
}

variable "denied_header_name" {
  type        = string
  description = "Lowercase HTTP header name used in the header deny rule."
  default     = "x-lab-block"
}

variable "denied_header_value" {
  type        = string
  description = "Header value that causes the edge policy to deny the request."
  default     = "1"
}

variable "enable_threat_intelligence" {
  type        = bool
  description = "Add Network Threat Intelligence deny rules (Tor exit nodes and known-malicious IPs). Requires Cloud Armor Enterprise in this project."
  default     = false
}
