output "firewall_policy_id" {
  value = google_compute_firewall_policy.lab.id
}

output "firewall_policy_name" {
  value = google_compute_firewall_policy.lab.name
}

output "attachment_target" {
  value = google_compute_firewall_policy_association.lab.attachment_target
}
