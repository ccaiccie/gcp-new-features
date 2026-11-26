output "gw_a_interfaces" {
  description = "Auto-assigned external IPv4 addresses for HA VPN Gateway A (interfaces 0 and 1)."
  value       = google_compute_ha_vpn_gateway.gw_a.vpn_interfaces
}

output "gw_b_interfaces" {
  description = "Auto-assigned external IPv4 addresses for HA VPN Gateway B (interfaces 0 and 1)."
  value       = google_compute_ha_vpn_gateway.gw_b.vpn_interfaces
}

output "router_a_name" {
  value = google_compute_router.router_a.name
}

output "router_b_name" {
  value = google_compute_router.router_b.name
}
