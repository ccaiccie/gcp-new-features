variable "project_id" {
  description = "Project where the lab VPC, MIG, load balancer, and Cloud Armor policy are created."
  type        = string
}

variable "region" {
  description = "Region for the subnet and managed instance group."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the managed instance group."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "grpc-lab"
}

variable "grpc_image" {
  description = "Container image for the sample gRPC server (listens on TCP port 9000, cleartext)."
  type        = string
  default     = "moul/grpcbin"
}

variable "machine_type" {
  description = "Machine type for the sample backend."
  type        = string
  default     = "e2-small"
}
