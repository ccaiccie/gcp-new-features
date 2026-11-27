output "vpc_name" {
  description = "Name of the created lab VPC network."
  value       = google_compute_network.lab_vpc.name
}

output "subnet_cidr" {
  description = "CIDR range of the lab subnet."
  value       = google_compute_subnetwork.lab_subnet.ip_cidr_range
}

output "vm_name" {
  description = "Name of the lab Compute Engine VM."
  value       = google_compute_instance.lab_vm.name
}

output "broken_route_name" {
  description = "Static route configured to trigger Network Analyzer invalid next-hop insight."
  value       = google_compute_route.broken_next_hop_route.name
}
