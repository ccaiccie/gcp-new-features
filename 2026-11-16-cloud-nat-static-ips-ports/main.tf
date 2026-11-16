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

locals {
  apis = ["compute.googleapis.com", "iap.googleapis.com"]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# A custom-mode VPC with one subnet. The VM has NO external IP address.
# ---------------------------------------------------------------------------
resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "lab" {
  name                     = "${var.name_prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Static regional external addresses: the allowlist you can hand to a partner.
resource "google_compute_address" "nat_default" {
  name         = "${var.name_prefix}-nat-default"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  depends_on = [google_project_service.apis]
}

resource "google_compute_address" "nat_partner" {
  name         = "${var.name_prefix}-nat-partner"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Cloud Router is the control plane that holds the NAT gateway configuration.
# ---------------------------------------------------------------------------
resource "google_compute_router" "lab" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.lab.id
}

resource "google_compute_router_nat" "lab" {
  name   = "${var.name_prefix}-nat"
  router = google_compute_router.lab.name
  region = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.nat_default.self_link]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.lab.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # Dynamic port allocation: each VM starts at the minimum and can grow to the maximum.
  # Endpoint-independent mapping must stay off, because the two features cannot be combined.
  enable_dynamic_port_allocation      = true
  enable_endpoint_independent_mapping = false
  min_ports_per_vm                    = var.min_ports_per_vm
  max_ports_per_vm                    = var.max_ports_per_vm

  tcp_time_wait_timeout_sec        = var.tcp_time_wait_timeout_sec
  tcp_established_idle_timeout_sec = 1200

  log_config {
    enable = true
    filter = var.nat_log_filter
  }

  # NAT rule: traffic to the partner range uses a different, dedicated static address.
  rules {
    rule_number = 100
    description = "Partner egress uses the partner allowlist address"
    match       = "destination.ip == '${var.partner_destination_cidr_ip}'"
    action {
      source_nat_active_ips = [google_compute_address.nat_partner.self_link]
    }
  }
}

# ---------------------------------------------------------------------------
# Optional test VM with no external IP. Reach it with IAP: gcloud compute ssh --tunnel-through-iap
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "iap_ssh" {
  count     = var.create_vm ? 1 : 0
  name      = "${var.name_prefix}-allow-iap-ssh"
  network   = google_compute_network.lab.name
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["nat-lab"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "client" {
  count        = var.create_vm ? 1 : 0
  name         = "${var.name_prefix}-client"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["nat-lab"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    # No access_config block: the VM has no external IP and relies on Cloud NAT.
  }

  depends_on = [google_compute_router_nat.lab]
}
