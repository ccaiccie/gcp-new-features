output "vpc_name" {
  value = google_compute_network.lab.name
}

output "cloud_router_name" {
  value = google_compute_router.lab.name
}

output "attachment_name" {
  value = google_compute_interconnect_attachment.partner.name
}

output "pairing_key" {
  description = "Give this pairing key to a Partner Interconnect provider if you complete the interconnect with that partner. This lab does not place a Lumen order."
  value       = google_compute_interconnect_attachment.partner.pairing_key
}

output "attachment_state" {
  value = google_compute_interconnect_attachment.partner.state
}
