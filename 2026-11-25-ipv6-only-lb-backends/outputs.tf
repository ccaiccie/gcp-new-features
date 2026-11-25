output "frontend_ipv4_address" {
  description = "External IPv4 address of the regional Application Load Balancer forwarding rule."
  value       = google_compute_address.frontend_ipv4.address
}

output "frontend_ipv6_address" {
  description = "External IPv6 /96 range allocated to the regional Application Load Balancer forwarding rule."
  value       = google_compute_address.frontend_ipv6.address
}

output "proxy_only_subnet_ipv6_cidr" {
  description = "Auto-allocated ULA IPv6 CIDR range of the dual-stack proxy-only subnet."
  value       = google_compute_subnetwork.proxy_only.ipv6_cidr_range
}

output "backend_service_name" {
  description = "Name of the regional backend service configured with ip_address_selection_policy = IPV6_ONLY."
  value       = google_compute_region_backend_service.ipv6_only.name
}
