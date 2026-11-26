output "perimeter_resource_name" {
  description = "Full Access Context Manager service perimeter resource name."
  value       = google_access_context_manager_service_perimeter.lab_perimeter.name
}

output "protected_bucket_name" {
  description = "Disposable Cloud Storage bucket inside the protected project."
  value       = google_storage_bucket.protected_demo_bucket.name
}

output "enforcement_mode" {
  description = "Current lab mode: dry-run-only or enforced."
  value       = var.enforce_perimeter ? "enforced" : "dry-run-only"
}

output "dry_run_audit_log_filter" {
  description = "Logs Explorer / gcloud logging read filter for dry-run violations."
  value       = "log_id(\"cloudaudit.googleapis.com/policy\") AND severity=\"error\" AND protoPayload.metadata.dryRun=\"true\""
}
