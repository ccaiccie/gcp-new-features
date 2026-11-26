output "internal_alb_ip" {
  description = "Internal IP address of the regional internal Application Load Balancer."
  value       = google_compute_forwarding_rule.ilb_fr.ip_address
}

output "forwarding_rule_name" {
  description = "Forwarding rule name targeted by AuthzPolicy."
  value       = google_compute_forwarding_rule.ilb_fr.name
}

output "forwarding_rule_self_link" {
  description = "Full forwarding rule URI for AuthzPolicy target.resources."
  value       = google_compute_forwarding_rule.ilb_fr.self_link
}

output "client_service_account_email" {
  description = "Service account attached to the test client VM."
  value       = google_service_account.client_sa.email
}

output "ssh_client_command" {
  description = "IAP SSH command to connect to the test client VM."
  value       = "gcloud compute ssh ${google_compute_instance.client_vm.name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"
}
