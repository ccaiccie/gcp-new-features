output "vpc_name" {
  value = google_compute_network.lab.name
}

output "secure_web_proxy_id" {
  value = google_network_services_gateway.swp.id
}

output "secure_web_proxy_addresses" {
  value = google_network_services_gateway.swp.addresses
}

output "agent_gateway_id" {
  value = google_network_services_agent_gateway.lab.id
}
