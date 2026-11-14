output "host_project_id" {
  description = "Shared VPC host project ID."
  value       = google_compute_shared_vpc_host_project.host.project
}

output "service_project_id" {
  description = "Attached service project ID."
  value       = google_compute_shared_vpc_service_project.service.service_project
}

output "network_name" {
  description = "Shared VPC network name in the host project."
  value       = google_compute_network.shared.name
}

output "subnet_self_link" {
  description = "Self link of the shared subnet."
  value       = google_compute_subnetwork.tier1.self_link
}

output "instance_name" {
  description = "Sample VM name in the service project."
  value       = google_compute_instance.sample.name
}

output "instance_internal_ip" {
  description = "Internal IPv4 address of the sample VM, allocated from the shared subnet."
  value       = google_compute_instance.sample.network_interface[0].network_ip
}

output "instance_subnetwork" {
  description = "Subnetwork the sample VM is attached to."
  value       = google_compute_instance.sample.network_interface[0].subnetwork
}
