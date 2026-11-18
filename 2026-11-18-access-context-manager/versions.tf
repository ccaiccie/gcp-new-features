terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
  }
}

# Access Context Manager calls made with user Application Default Credentials need a
# quota/billing project, otherwise the API returns 403 (see the provider docs for
# google_access_context_manager_access_policy).
provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
