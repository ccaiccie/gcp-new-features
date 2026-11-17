variable "project_id" {
  type        = string
  description = "Project that will hold the lab."
}

variable "region" {
  type        = string
  description = "Region for the subnets."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zone for the two test VMs."
  default     = "us-central1-a"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "ctlab"
}

variable "subnet_a_cidr" {
  type        = string
  description = "Subnet A (source)."
  default     = "10.90.1.0/24"
}

variable "subnet_b_cidr" {
  type        = string
  description = "Subnet B (destination)."
  default     = "10.90.2.0/24"
}

variable "allowed_port" {
  type        = number
  description = "Port opened by the firewall rule from subnet A to tag web."
  default     = 8080
}

variable "blocked_port" {
  type        = number
  description = "Port with no allow rule; expected to hit the implied deny ingress rule."
  default     = 5432
}

variable "machine_type" {
  type        = string
  description = "Machine type of the test VMs."
  default     = "e2-micro"
}
