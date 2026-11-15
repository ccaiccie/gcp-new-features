variable "host_project_id" {
  description = "Project ID of the Shared VPC host project. Owns the VPC, attachment subnet, PSC endpoint, and private DNS zones."
  type        = string
}

variable "service_project_id" {
  description = "Project ID of the service project. Owns the network attachment, Agent Gateway, connectivity template, and Cloud Run service."
  type        = string
}

variable "region" {
  description = "Region for the subnet, network attachment, Agent Gateway, connectivity template, and Cloud Run service. Custom MCP plus egress Agent Gateway is documented in us-central1 and europe-west1."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "agw-mcp-lab"
}

variable "network_name" {
  description = "Name of the Shared VPC network created in the host project."
  type        = string
  default     = "agw-mcp-shared-vpc"
}

variable "attachment_subnet_name" {
  description = "Name of the host-project subnet used by the PSC network attachment."
  type        = string
  default     = "agw-attachment"
}

variable "attachment_subnet_cidr" {
  description = "IPv4 range of the network attachment subnet. Must not overlap the PSC Google APIs /32."
  type        = string
  default     = "10.8.0.0/24"
}

variable "psc_google_apis_ip" {
  description = "Reserved global IPv4 /32 for the Private Service Connect endpoint for Google APIs. Must not overlap any subnet in the VPC. 172.16.20.20 is the address used in the official walkthrough and is only a lab default."
  type        = string
  default     = "172.16.20.20"
}

variable "dns_zone_dns_name" {
  description = "DNS suffix of the private Cloud DNS zone authorized for the Shared VPC. Must end with a trailing dot. The connectivity template peers this suffix."
  type        = string
  default     = "run.app."
}

variable "mcp_service_name" {
  description = "Cloud Run service name for the stand-in MCP server."
  type        = string
  default     = "agw-mcp-lab"
}

variable "mcp_image" {
  description = "Container image for the Cloud Run service. Replace this with your StreamableHTTP MCP server image before using the service as a real connector."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "create_agent_gateway" {
  description = "When true, create the Agent Connectivity Template and egress Agent Gateway in the service project. Set false if you only want the network, PSC, DNS, and Cloud Run resources."
  type        = bool
  default     = true
}
