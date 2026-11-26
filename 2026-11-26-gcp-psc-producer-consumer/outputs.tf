output "service_attachment_uri" {
  description = "Producer Service Attachment self_link URI."
  value       = google_compute_service_attachment.producer_sa.id
}

output "consumer_endpoint_ip" {
  description = "Internal IP address of the consumer PSC endpoint in consumer_vpc."
  value       = google_compute_address.consumer_psc_ip.address
}

output "consumer_psc_connection_id" {
  description = "Globally unique 8-byte PSC connection ID for this endpoint."
  value       = google_compute_forwarding_rule.consumer_psc_endpoint.psc_connection_id
}

output "consumer_psc_connection_status" {
  description = "Current PSC connection status (ACCEPTED, PENDING, REJECTED, CLOSED, NEEDS_ATTENTION)."
  value       = google_compute_forwarding_rule.consumer_psc_endpoint.psc_connection_status
}

output "private_dns_fqdn" {
  description = "Private Cloud DNS FQDN pointing to the consumer PSC endpoint IP."
  value       = trimsuffix(google_dns_record_set.consumer_service_a_record.name, ".")
}

output "verification_command" {
  description = "Run this from the consumer test VM via IAP SSH to verify DNS and HTTP reachability."
  value       = "curl -v http://${trimsuffix(google_dns_record_set.consumer_service_a_record.name, ".")}/"
}
