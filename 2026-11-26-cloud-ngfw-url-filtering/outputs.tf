output "ssh_command" {
  description = "Connect to the private test VM through Identity-Aware Proxy (IAP)."
  value       = "gcloud compute ssh ${google_compute_instance.test_vm.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "logs_explorer_query" {
  description = "Logs Explorer query to inspect Cloud NGFW URL filtering allow and deny entries."
  value       = "resource.type=\"networksecurity.googleapis.com/FirewallEndpoint\" logName=\"projects/${var.project_id}/logs/networksecurity.googleapis.com%2Ffirewall_url_filter\""
}

output "security_profile_id" {
  description = "Created URL filtering security profile resource ID."
  value       = google_network_security_security_profile.urlf_profile.id
}

output "security_profile_group_id" {
  description = "Created security profile group resource ID."
  value       = google_network_security_security_profile_group.urlf_group.id
}

output "firewall_endpoint_id" {
  description = "Created zonal Cloud NGFW firewall endpoint resource ID."
  value       = google_network_security_firewall_endpoint.endpoint.id
}
