output "edge_policy_name" {
  description = "Name of the CLOUD_ARMOR_EDGE security policy."
  value       = google_compute_security_policy.edge.name
}

output "backend_bucket_name" {
  description = "Backend bucket that has Cloud CDN enabled and the edge policy attached."
  value       = google_compute_backend_bucket.cdn.name
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket behind the backend bucket."
  value       = google_storage_bucket.lab.name
}

output "attach_backend_bucket_command" {
  description = "gcloud command that attaches the edge policy to the backend bucket (Terraform already does this)."
  value       = "gcloud compute backend-buckets update ${google_compute_backend_bucket.cdn.name} --edge-security-policy=${google_compute_security_policy.edge.name}"
}

output "attach_backend_service_command" {
  description = "Example gcloud command for a CDN-enabled backend service. Replace BACKEND_SERVICE with your service name."
  value       = "gcloud compute backend-services update BACKEND_SERVICE --edge-security-policy=${google_compute_security_policy.edge.name}"
}

output "threat_intelligence_enabled" {
  description = "Whether the optional NTI deny rules were created."
  value       = var.enable_threat_intelligence
}
