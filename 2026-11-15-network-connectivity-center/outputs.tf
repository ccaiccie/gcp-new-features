output "hub_id" {
  description = "Resource ID of the star-topology NCC hub."
  value       = google_network_connectivity_hub.lab.id
}

output "center_spoke_id" {
  description = "Resource ID of the center VPC spoke."
  value       = google_network_connectivity_spoke.center.id
}

output "edge_a_spoke_id" {
  description = "Resource ID of the edge A VPC spoke."
  value       = google_network_connectivity_spoke.edge_a.id
}

output "edge_b_spoke_id" {
  description = "Resource ID of the edge B VPC spoke."
  value       = google_network_connectivity_spoke.edge_b.id
}

output "center_vm" {
  description = "Name and internal IP of the center sample VM."
  value = {
    name        = google_compute_instance.center.name
    internal_ip = google_compute_instance.center.network_interface[0].network_ip
    network     = google_compute_network.center.name
  }
}

output "edge_a_vm" {
  description = "Name and internal IP of the edge A sample VM."
  value = {
    name        = google_compute_instance.edge_a.name
    internal_ip = google_compute_instance.edge_a.network_interface[0].network_ip
    network     = google_compute_network.edge_a.name
  }
}

output "edge_b_vm" {
  description = "Name and internal IP of the edge B sample VM."
  value = {
    name        = google_compute_instance.edge_b.name
    internal_ip = google_compute_instance.edge_b.network_interface[0].network_ip
    network     = google_compute_network.edge_b.name
  }
}

output "verify_hint" {
  description = "How to confirm star-topology routing after apply."
  value       = "From the edge-a VM, ping the center VM (should succeed) and the edge-b VM (should fail). Use IAP: gcloud compute ssh ${google_compute_instance.edge_a.name} --zone=${var.zone} --tunnel-through-iap"
}
