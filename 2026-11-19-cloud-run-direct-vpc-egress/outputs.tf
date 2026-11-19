output "run_subnet" {
  description = "Subnet used by Direct VPC egress."
  value       = google_compute_subnetwork.run.ip_cidr_range
}

output "backend_ip" {
  description = "Private address of the backend VM."
  value       = google_compute_instance.backend.network_interface[0].network_ip
}

output "nat_static_ip" {
  description = "The address the internet should see when vpc_egress = ALL_TRAFFIC."
  value       = google_compute_address.nat.address
}

output "job_name" {
  description = "Cloud Run job that uses Direct VPC egress."
  value       = google_cloud_run_v2_job.probe.name
}

output "run_job_command" {
  description = "Run the probe job and wait for it."
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.probe.name} --region ${var.region} --wait"
}

output "connector_job_name" {
  description = "Optional Cloud Run job that uses the connector."
  value       = var.create_connector ? google_cloud_run_v2_job.probe_connector[0].name : null
}
