output "vpc_name" {
  description = "VPC network name."
  value       = google_compute_network.lab_vpc.name
}

output "pga_enabled_subnet" {
  description = "Subnet with Private Google Access enabled."
  value       = google_compute_subnetwork.pga_enabled.name
}

output "vm_name" {
  description = "Private test VM name."
  value       = google_compute_instance.test_vm.name
}

output "vm_zone" {
  description = "Zone where the private test VM runs."
  value       = google_compute_instance.test_vm.zone
}

output "vm_internal_ip" {
  description = "Internal IP address of the private test VM."
  value       = google_compute_instance.test_vm.network_interface[0].network_ip
}

output "psc_endpoint_ip" {
  description = "Global internal IPv4 address of the PSC endpoint."
  value       = google_compute_global_address.psc_api_ip.address
}

output "psc_storage_fqdn" {
  description = "Private DNS name for Cloud Storage via the PSC endpoint."
  value       = "storage-${var.psc_endpoint_name}.p.googleapis.com"
}
