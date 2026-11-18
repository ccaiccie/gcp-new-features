output "azure_paired_region" {
  description = "Azure region paired with the chosen Google Cloud region."
  value       = local.azure_pair[var.region]
}

output "vpc" {
  value = google_compute_network.lab.id
}

output "transport_id" {
  value = try(google_network_connectivity_transport.azure[0].id, null)
}

output "transport_state" {
  description = "State of the underlying connectivity."
  value       = try(google_network_connectivity_transport.azure[0].state, null)
}

output "pairing_key" {
  description = "Google-generated activation (pairing) key to enter on the Azure side."
  value       = try(google_network_connectivity_transport.azure[0].generated_activation_key, null)
  sensitive   = true
}

output "peering_network" {
  description = "VPC created for the VPC Network Peering connection (peering mode)."
  value       = try(google_network_connectivity_transport.azure[0].peering_network, null)
}

output "mtu_limit" {
  value = try(google_network_connectivity_transport.azure[0].mtu_limit, null)
}
