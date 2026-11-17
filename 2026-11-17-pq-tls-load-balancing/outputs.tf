output "ssl_policy_keep_name" {
  description = "SSL policy with post_quantum_key_exchange = DEFAULT (Phase 2 behavior)."
  value       = google_compute_ssl_policy.keep.name
}

output "ssl_policy_deferred_name" {
  description = "SSL policy with post_quantum_key_exchange = DEFERRED (opt out until October 2027)."
  value       = google_compute_ssl_policy.deferred.name
}

output "attached_ssl_policy_mode" {
  description = "Which policy is attached to the target HTTPS proxy."
  value       = var.create_load_balancer ? var.ssl_policy_mode : "no load balancer; policies only"
}

output "target_https_proxy_name" {
  description = "Target HTTPS proxy that has the selected SSL policy attached."
  value       = var.create_load_balancer ? google_compute_target_https_proxy.lab[0].name : null
}

output "forwarding_ip" {
  description = "Reserved global IPv4 address of the HTTPS forwarding rule."
  value       = var.create_load_balancer ? google_compute_global_address.lab[0].address : null
}

output "attach_default_command" {
  description = "gcloud command that attaches the DEFAULT policy to the lab target proxy."
  value       = var.create_load_balancer ? "gcloud compute target-https-proxies update ${google_compute_target_https_proxy.lab[0].name} --ssl-policy=${google_compute_ssl_policy.keep.name}" : "gcloud compute target-https-proxies update TARGET --ssl-policy=${google_compute_ssl_policy.keep.name}"
}

output "attach_deferred_command" {
  description = "gcloud command that attaches the DEFERRED policy to the lab target proxy."
  value       = var.create_load_balancer ? "gcloud compute target-https-proxies update ${google_compute_target_https_proxy.lab[0].name} --ssl-policy=${google_compute_ssl_policy.deferred.name}" : "gcloud compute target-https-proxies update TARGET --ssl-policy=${google_compute_ssl_policy.deferred.name}"
}
