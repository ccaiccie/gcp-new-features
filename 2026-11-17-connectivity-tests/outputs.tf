output "allowed_test" {
  description = "Connectivity Test expected to be REACHABLE."
  value       = google_network_management_connectivity_test.allowed.name
}

output "blocked_test" {
  description = "Connectivity Test expected to be UNREACHABLE."
  value       = google_network_management_connectivity_test.blocked.name
}

output "describe_commands" {
  description = "Commands to inspect the results."
  value = [
    "gcloud network-management connectivity-tests describe ${google_network_management_connectivity_test.allowed.name} --project ${var.project_id}",
    "gcloud network-management connectivity-tests describe ${google_network_management_connectivity_test.blocked.name} --project ${var.project_id}",
  ]
}
