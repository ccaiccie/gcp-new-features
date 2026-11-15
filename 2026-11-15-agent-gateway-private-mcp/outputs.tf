output "host_network" {
  description = "Shared VPC network in the host project."
  value       = google_compute_network.host.id
}

output "attachment_subnet" {
  description = "Host-project subnet used by the network attachment. This range is the source IP range for gateway egress."
  value       = google_compute_subnetwork.attachment.id
}

output "network_attachment" {
  description = "PSC network attachment in the service project, referencing the host subnet."
  value       = google_compute_network_attachment.agw.id
}

output "psc_google_apis_ip" {
  description = "Reserved /32 of the PSC endpoint for Google APIs."
  value       = google_compute_global_address.psc_googleapis.address
}

output "psc_google_apis_forwarding_rule" {
  description = "Global forwarding rule for the all-apis PSC endpoint."
  value       = google_compute_global_forwarding_rule.psc_googleapis.id
}

output "private_dns_zone" {
  description = "Private Cloud DNS zone in the host project, authorized for the Shared VPC."
  value       = google_dns_managed_zone.run_app.id
}

output "cloud_run_uri" {
  description = "Default Cloud Run URL (ends in run.app). Replace the image with a StreamableHTTP MCP server before attaching this as a connector."
  value       = google_cloud_run_v2_service.mcp.uri
}

output "agent_connectivity_template" {
  description = "Connectivity template resource name, if created."
  value       = var.create_agent_gateway ? google_network_services_agent_connectivity_template.agw[0].id : null
}

output "agent_gateway" {
  description = "Egress Agent Gateway resource name, if created."
  value       = var.create_agent_gateway ? google_network_services_agent_gateway.agw[0].id : null
}

output "next_steps" {
  description = "Manual steps that provider 8.11.0 does not cover: authorization policy, Gemini Enterprise app binding, and connector routing."
  value       = "Bind an authorization policy to the gateway (HTTP 403 until you do). In the Gemini Enterprise app, set agentGatewaySetting and turn on Route egress through Agent Gateway for the custom MCP connector. Grant is already applied for the Discovery Engine service agent as Cloud Run Invoker; dual-header OAuth still needs an OAuth client and connector config. See README.md."
}
