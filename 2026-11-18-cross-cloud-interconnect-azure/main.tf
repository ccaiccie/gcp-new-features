locals {
  # Paired locations for Azure (Google Cloud docs, "Choose a paired location").
  azure_pair = {
    "us-east4"     = "eastus (Washington D.C.)"
    "us-west2"     = "westus (Silicon Valley)"
    "europe-west3" = "germanywestcentral (Frankfurt)"
  }
  use_ncc = var.connection_mode == "ncc"
}

resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "networkconnectivity.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "this" {}

# The Google Cloud side: a custom-mode VPC with one subnet in the transport region.
resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-${var.region}"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.lab.id
}

# Allow ICMP and SSH from the Azure VNet for testing.
resource "google_compute_firewall" "from_azure" {
  name          = "${var.name_prefix}-allow-from-azure"
  network       = google_compute_network.lab.name
  direction     = "INGRESS"
  source_ranges = [var.azure_vnet_cidr]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Option 2: attach the transport to a Network Connectivity Center hub (mesh topology by default).
resource "google_network_connectivity_hub" "lab" {
  count       = local.use_ncc ? 1 : 0
  name        = "${var.name_prefix}-hub"
  description = "Hub for the partner Cross-Cloud Interconnect to Azure lab"
  depends_on  = [google_project_service.apis]
}

# The managed cross-cloud connection. No ports, LOAs, VLAN attachments or BGP sessions to configure.
resource "google_network_connectivity_transport" "azure" {
  count             = var.create_transport ? 1 : 0
  name              = "${var.name_prefix}-transport"
  region            = var.region
  description       = "Partner Cross-Cloud Interconnect to Azure ${local.azure_pair[var.region]}"
  remote_profile    = "https://networkconnectivity.googleapis.com/v1/${data.google_project.this.id}/locations/${var.region}/remoteTransportProfiles/${var.remote_profile_name}"
  remote_account_id = var.remote_account_id
  bandwidth         = var.bandwidth
  stack_type        = "IPV4_ONLY"
  advertised_routes = length(var.advertised_routes) > 0 ? var.advertised_routes : null

  # Exactly one of network (VPC Network Peering) or hub (NCC).
  network     = local.use_ncc ? null : google_compute_network.lab.name
  hub         = local.use_ncc ? google_network_connectivity_hub.lab[0].id : null
  auto_accept = local.use_ncc ? true : null

  labels = {
    lab = "pcci-azure"
  }

  lifecycle {
    precondition {
      condition     = var.remote_profile_name != "" && var.remote_account_id != ""
      error_message = "Set remote_profile_name and remote_account_id before create_transport = true."
    }
  }
}
