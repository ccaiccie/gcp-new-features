output "vpc_name" {
  value = google_compute_network.lab.name
}

output "ipv4_frontend_ip" {
  value = google_compute_forwarding_rule.ipv4.ip_address
}

output "ipv6_frontend_ip" {
  description = "IPv6 /96 allocated to the regional external forwarding rule."
  value       = google_compute_forwarding_rule.ipv6.ip_address
}

output "target_tcp_proxy" {
  value = google_compute_region_target_tcp_proxy.lab.name
}

output "tls_route" {
  value = google_network_services_tls_route.lab.name
}

output "app_backend_service" {
  value = google_compute_region_backend_service.app.name
}

output "api_backend_service" {
  value = google_compute_region_backend_service.api.name
}
