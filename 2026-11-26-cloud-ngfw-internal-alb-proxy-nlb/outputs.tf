output "vpc_name" {
  description = "Name of the lab VPC network."
  value       = google_compute_network.lab_vpc.name
}

output "internal_alb_ip" {
  description = "Internal IP address of the Regional Internal Application Load Balancer forwarding rule."
  value       = google_compute_forwarding_rule.internal_alb.ip_address
}

output "internal_alb_forwarding_rule_ref" {
  description = "Forwarding rule path used by Cloud NGFW target_forwarding_rules."
  value       = local.alb_forwarding_rule_ref
}

output "internal_proxy_nlb_ip" {
  description = "Internal IP address of the optional Regional Internal Proxy Network Load Balancer (port 8080)."
  value       = var.enable_proxy_nlb ? google_compute_forwarding_rule.internal_proxy_nlb[0].ip_address : "disabled (set enable_proxy_nlb = true)"
}

output "client_allowed_ip" {
  description = "Internal IP address of the approved test client VM."
  value       = google_compute_instance.client_allowed.network_interface[0].network_ip
}

output "client_blocked_ip" {
  description = "Internal IP address of the blocked test client VM."
  value       = google_compute_instance.client_blocked.network_interface[0].network_ip
}

output "regional_firewall_policy_name" {
  description = "Name of the Cloud NGFW Regional Network Firewall Policy."
  value       = google_compute_region_network_firewall_policy.ilb_policy.name
}
