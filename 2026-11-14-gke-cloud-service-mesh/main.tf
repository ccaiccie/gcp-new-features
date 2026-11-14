terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "lab" {
  count    = var.create_cluster ? 1 : 0
  name     = "${var.name_prefix}-cluster"
  location = var.region
  project  = var.project_id

  enable_autopilot    = true
  deletion_protection = false
}

resource "google_gke_hub_membership" "lab" {
  count         = var.create_cluster ? 1 : 0
  membership_id = "${var.name_prefix}-membership"
  project       = var.project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.lab[0].id}"
    }
  }
}

resource "google_gke_hub_feature" "mesh" {
  name     = "servicemesh"
  location = "global"
  project  = var.project_id
}

resource "google_gke_hub_feature_membership" "mesh" {
  count      = var.create_cluster ? 1 : 0
  location   = "global"
  feature    = google_gke_hub_feature.mesh.name
  membership = google_gke_hub_membership.lab[0].membership_id
  project    = var.project_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }
}
