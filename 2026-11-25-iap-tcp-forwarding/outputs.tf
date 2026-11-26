output "private_vm_name" {
  value = google_compute_instance.private_vm.name
}

output "private_vm_internal_ip" {
  value = google_compute_instance.private_vm.network_interface[0].network_ip
}

output "iap_firewall_rule" {
  value = google_compute_firewall.allow_iap_tcp.name
}

output "iap_backend_service" {
  value = google_compute_backend_service.iap_https_backend.name
}

output "gcloud_verify_commands" {
  value = <<-EOT
    gcloud compute firewall-rules describe ${google_compute_firewall.allow_iap_tcp.name} --project ${var.project_id}
    gcloud compute ssh ${google_compute_instance.private_vm.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap
    gcloud compute backend-services describe ${google_compute_backend_service.iap_https_backend.name} --global --project ${var.project_id} --format="value(iap.enabled)"
  EOT
}
