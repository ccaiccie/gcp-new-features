output "dns_authorization_cname" {
  description = "Publish this CNAME record in your public DNS zone so Certificate Manager can validate ownership and auto-renew the certificate."
  value = {
    name = google_certificate_manager_dns_authorization.default.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.default.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.default.dns_resource_record[0].data
  }
}

output "certificate_name" {
  description = "Certificate Manager certificate resource name."
  value       = google_certificate_manager_certificate.default.name
}

output "certificate_map_id" {
  description = "Full resource ID of the Certificate Map attached to the Target HTTPS Proxy."
  value       = google_certificate_manager_certificate_map.default.id
}

output "load_balancer_ip" {
  description = "Reserved global external IPv4 address of the Application Load Balancer forwarding rule."
  value       = google_compute_global_address.lb_ip.address
}
