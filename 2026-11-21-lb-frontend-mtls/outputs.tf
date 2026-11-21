output "lb_ip" {
  description = "Load balancer frontend IP address."
  value       = google_compute_global_address.lb.address
}

output "server_hostname" {
  description = "Hostname in the server certificate (use with curl --resolve)."
  value       = var.server_hostname
}

output "client_validation_mode" {
  value = var.client_validation_mode
}

output "trust_config" {
  value = google_certificate_manager_trust_config.lab.id
}

output "server_tls_policy" {
  value = google_network_security_server_tls_policy.mtls.id
}

output "test_command" {
  value = "./scripts/test-clients.sh ${google_compute_global_address.lb.address} ${var.server_hostname}"
}
