output "access_policy" {
  description = "Access policy used by the lab (accessPolicies/NUMBER)."
  value       = local.policy
}

output "access_levels" {
  description = "Full resource names of the access levels."
  value = compact([
    google_access_context_manager_access_level.corp_network.name,
    google_access_context_manager_access_level.allowed_regions.name,
    google_access_context_manager_access_level.corp_and_region.name,
    google_access_context_manager_access_level.office_hours.name,
    try(google_access_context_manager_access_level.managed_device[0].name, ""),
  ])
}

output "perimeter" {
  description = "Dry-run service perimeter name."
  value       = google_access_context_manager_service_perimeter.lab.name
}

output "test_bucket" {
  description = "Bucket inside the dry-run perimeter."
  value       = try(google_storage_bucket.test[0].name, null)
}

output "iap_condition_example" {
  description = "IAM condition expression for an IAP binding. Only valid with an ORGANIZATION-level policy; IAP does not support scoped policies."
  value       = "\"${google_access_context_manager_access_level.corp_network.name}\" in request.auth.access_levels"
}
