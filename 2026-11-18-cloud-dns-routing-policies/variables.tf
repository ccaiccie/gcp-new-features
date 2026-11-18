variable "project_id" {
  type        = string
  description = "Project for the lab."
}

variable "region" {
  type        = string
  description = "Default region for the provider."
  default     = "us-east4"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "dnsrp"
}

variable "dns_domain" {
  type        = string
  description = "Domain for the public test zone, with the trailing dot. It does not need to be delegated; query the zone's own name servers."
  default     = "dnslab.example.com."
}

variable "ttl" {
  type        = number
  description = "TTL for steered records. Short TTLs limit stale answers in resolver caches."
  default     = 30
}

variable "canary_current_ip" {
  type        = string
  description = "Address of the current platform (canary record, weight canary_current_weight)."
  default     = "203.0.113.10"
}

variable "canary_new_ip" {
  type        = string
  description = "Address of the new platform (canary record, weight canary_new_weight)."
  default     = "203.0.113.20"
}

variable "canary_current_weight" {
  type        = number
  description = "WRR weight of the current platform (0 to 1000)."
  default     = 900
}

variable "canary_new_weight" {
  type        = number
  description = "WRR weight of the new platform (0 to 1000)."
  default     = 100
}

variable "europe_endpoint_ip" {
  type        = string
  description = "Internet-reachable endpoint for Europe (for example a regional external Application Load Balancer in europe-west3)."
  default     = "198.51.100.10"
}

variable "us_endpoint_ip" {
  type        = string
  description = "Internet-reachable endpoint for the US (for example a regional external Application Load Balancer in us-east4)."
  default     = "198.51.100.20"
}

variable "health_check_port" {
  type        = number
  description = "TCP port the Cloud DNS probers connect to. Allow it from any source on the endpoints."
  default     = 80
}

variable "health_check_source_regions" {
  type        = list(string)
  description = "Exactly three source regions for the Cloud DNS health check probers."
  default     = ["us-east4", "europe-west3", "us-central1"]

  validation {
    condition     = length(var.health_check_source_regions) == 3
    error_message = "Cloud DNS external endpoint health checks use exactly three source regions."
  }
}

variable "enable_geo_fencing" {
  type        = bool
  description = "Geofencing on the geolocation record: keep answers in the nearest region even if unhealthy."
  default     = false
}

variable "trickle_ratio" {
  type        = number
  description = "Fraction of traffic sent to the backup in the failover record (0 to 1; 1 forces a failover)."
  default     = 0.1
}
