output "network" {
  value = google_compute_network.vpc.name
}

output "vpc_ula_range" {
  description = "The /48 ULA range Google assigned to the VPC (inside fd20::/20)."
  value       = google_compute_network.vpc.internal_ipv6_range
}

output "node_subnet_ipv6_range" {
  description = "The /64 internal IPv6 range of the node subnet."
  value       = google_compute_subnetwork.nodes.internal_ipv6_prefix
}

output "nat64_external_ip" {
  description = "The IPv4 address IPv4-only destinations see for NAT64 traffic."
  value       = google_compute_address.nat64.address
}

output "cluster_create_command" {
  description = "The gcloud command Terraform runs (or that you run when create_cluster = false)."
  value       = local.cluster_create_cmd
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${local.cluster_name} --project=${var.project_id} --location=${var.cluster_location} --dns-endpoint"
}

output "axion_node_pool_command" {
  description = "Optional: add an Arm (Axion, C4A) node pool. Check that C4A is offered in your zone first."
  value       = "gcloud container node-pools create axion-pool --cluster=${local.cluster_name} --project=${var.project_id} --location=${var.cluster_location} --machine-type=c4a-standard-4 --num-nodes=1"
}
