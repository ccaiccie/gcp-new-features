output "apigee_org" {
  value = google_apigee_organization.org.id
}

output "networking_mode" {
  value = var.networking_mode
}

output "instance_host" {
  description = "Internal IP address of the Apigee runtime instance (reachable over peering in peering mode)."
  value       = google_apigee_instance.runtime.host
}

output "instance_service_attachment" {
  description = "Service attachment that a PSC NEG or PSC endpoint connects to (northbound)."
  value       = google_apigee_instance.runtime.service_attachment
}

output "envgroup_hostname" {
  value = local.hostname
}

output "lb_ip" {
  value = try(google_compute_global_address.lb[0].address, null)
}

output "test_url" {
  description = "Call this after you deploy a proxy with base path /hello to one of the environments. The managed certificate can take a while to become ACTIVE."
  value       = var.create_northbound_lb ? "https://${local.hostname}/hello" : null
}

output "endpoint_attachment_host" {
  description = "Southbound: use this IP (or a private DNS name for it) as the TargetEndpoint URL host in your proxy."
  value       = try(google_apigee_endpoint_attachment.backend[0].host, null)
}

output "endpoint_attachment_state" {
  value = try(google_apigee_endpoint_attachment.backend[0].connection_state, null)
}
