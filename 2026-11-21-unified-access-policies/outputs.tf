output "netops_sa" {
  value = google_service_account.netops.email
}

output "breakglass_sa" {
  value = google_service_account.breakglass.email
}

output "access_policy" {
  value = google_iam_project_access_policy.network_guardrail.name
}

output "policy_binding" {
  value = google_iam_projects_policy_binding.network_guardrail.name
}

output "test_command" {
  value = "./scripts/test-access.sh ${var.project_id} ${google_service_account.netops.email} ${google_service_account.breakglass.email} ${google_compute_network.lab.name}"
}
