output "load_balancer_ip" {
  description = "Global external Application Load Balancer IPv4 address."
  value       = google_compute_global_address.lb_ip.address
}

output "security_policy_name" {
  description = "Cloud Armor security policy name."
  value       = google_compute_security_policy.armor_policy.name
}
