resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "container.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "nodes" {
  name          = "${var.name_prefix}-nodes"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.nodes_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# SSH through IAP so you can count iptables rules on a node before and after.
resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# VPC-native cluster that starts on the legacy datapath (Dataplane V1: iptables + kube-proxy).
#
# datapath_provider is ForceNew in hashicorp/google 8.12.0 (and google-beta 8.12.0):
# changing it in Terraform destroys and recreates the cluster. The in-place migration is
# therefore done with gcloud (scripts/), and Terraform is told to ignore the field so a
# plan during or after the migration (MIGRATE_TO_ADVANCED_DATAPATH, then ADVANCED_DATAPATH)
# never proposes a replacement.
resource "google_container_cluster" "lab" {
  name     = "${var.name_prefix}-cluster"
  location = var.cluster_location

  network         = google_compute_network.vpc.id
  subnetwork      = google_compute_subnetwork.nodes.id
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  datapath_provider = "LEGACY_DATAPATH"

  # No Calico network policy: clusters with network policy (Calico) enabled can't migrate directly.
  network_policy {
    enabled = false
  }

  release_channel {
    channel = var.release_channel
  }

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  dynamic "maintenance_policy" {
    for_each = var.enable_maintenance_window ? [1] : []
    content {
      recurring_window {
        start_time = "2026-11-21T04:00:00Z"
        end_time   = "2026-11-21T10:00:00Z"
        recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
      }
    }
  }

  lifecycle {
    ignore_changes = [datapath_provider]
  }
}

resource "google_container_node_pool" "pool" {
  name       = "${var.name_prefix}-pool"
  cluster    = google_container_cluster.lab.id
  location   = var.cluster_location
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Surge settings decide how many extra nodes (and Pod /24s) exist during the migration.
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
