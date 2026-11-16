output "default_nat_ip" {
  description = "Static address used for general internet egress."
  value       = google_compute_address.nat_default.address
}

output "partner_nat_ip" {
  description = "Static address used when the destination matches the NAT rule."
  value       = google_compute_address.nat_partner.address
}

output "nat_gateway" {
  description = "Cloud NAT gateway name."
  value       = google_compute_router_nat.lab.name
}

output "client_ssh_command" {
  description = "SSH to the test VM through IAP."
  value       = var.create_vm ? "gcloud compute ssh ${var.name_prefix}-client --zone ${var.zone} --tunnel-through-iap --project ${var.project_id}" : "VM not created"
}
