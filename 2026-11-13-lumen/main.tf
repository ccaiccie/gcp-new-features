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

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.lab.id
}

resource "google_compute_router" "lab" {
  name    = "${var.name_prefix}-router"
  network = google_compute_network.lab.id
  region  = var.region
  bgp {
    asn = var.cloud_router_asn
  }
}

# Google-side Partner Interconnect VLAN attachment. After apply, give the
# pairing key to a supported interconnect partner. This is not a Lumen order.
resource "google_compute_interconnect_attachment" "partner" {
  name                     = "${var.name_prefix}-partner-vlan"
  region                   = var.region
  router                   = google_compute_router.lab.id
  type                     = "PARTNER"
  edge_availability_domain = var.edge_availability_domain
  mtu                      = var.mtu
}
