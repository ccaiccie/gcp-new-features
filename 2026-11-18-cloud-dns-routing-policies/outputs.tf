output "name_servers" {
  description = "Query these directly with dig; the test domain does not need to be delegated."
  value       = google_dns_managed_zone.lab.name_servers
}

output "records" {
  description = "Steered names created by the lab."
  value = {
    canary_wrr = google_dns_record_set.canary.name
    geo        = google_dns_record_set.geo.name
    failover   = google_dns_record_set.failover.name
  }
}

output "health_check" {
  description = "Global health check used by the geolocation and failover records."
  value       = google_compute_health_check.endpoints.self_link
}
