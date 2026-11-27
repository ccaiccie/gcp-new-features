# ---------------------------------------------------------------------------
# Google Cloud Network Intelligence Center Practice Lab
# Firewall Insights + Network Analyzer
#
# COST WARNING:
# Compute Engine VMs, reserved IP addresses, and Firewall Rules Logging
# (Cloud Logging ingestion) can incur charges until deleted or disabled.
# Run this lab ONLY in a disposable project and run `terraform destroy`
# when finished.
# ---------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "firewallinsights.googleapis.com",
    "recommender.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "lab_vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "lab_subnet" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = "10.42.0.0/24"
  region        = var.region
  network       = google_compute_network.lab_vpc.id
}

# Test VM with IP forwarding DISABLED (default: false).
# Used both as a firewall target and as the invalid next hop for the
# Network Analyzer route insight (ROUTE_NEXT_HOP_VM_IP_FORWARDING_DISABLED).
resource "google_compute_instance" "lab_vm" {
  name           = "${var.name_prefix}-vm"
  machine_type   = var.machine_type
  zone           = var.zone
  can_ip_forward = false
  tags           = ["web-lab"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab_subnet.id
    # No external IP needed; use IAP or internal traffic if desired.
  }

  depends_on = [google_project_service.required_apis]
}

# ---------------------------------------------------------------------------
# Intentionally Messy VPC Firewall Rules (for Firewall Insights)
# All rules enable Firewall Rules Logging so log-based insights and metrics
# can be generated. Disable logging or destroy the lab when finished.
# ---------------------------------------------------------------------------

# 1. Overly permissive allow rule (broad 0.0.0.0/0 source and wide port range)
resource "google_compute_firewall" "allow_broad_web" {
  name        = "${var.name_prefix}-allow-broad-web"
  network     = google_compute_network.lab_vpc.name
  direction   = "INGRESS"
  priority    = 1000
  target_tags = ["web-lab"]

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080-8090"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 2. Shadowed allow rule (lower priority 1100, narrower CIDR & port subset
#    already covered by nic-lab-allow-broad-web at priority 1000)
resource "google_compute_firewall" "allow_shadowed_web" {
  name        = "${var.name_prefix}-allow-shadowed-web"
  network     = google_compute_network.lab_vpc.name
  direction   = "INGRESS"
  priority    = 1100
  target_tags = ["web-lab"]

  source_ranges = ["10.42.0.0/24"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 3. Unused allow rule (no traffic hits expected during the observation period)
resource "google_compute_firewall" "allow_unused_legacy" {
  name        = "${var.name_prefix}-allow-unused-legacy"
  network     = google_compute_network.lab_vpc.name
  direction   = "INGRESS"
  priority    = 1000
  target_tags = ["web-lab"]

  source_ranges = ["10.99.0.0/24"]

  allow {
    protocol = "tcp"
    ports    = ["9000"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 4. Explicit deny rule with logging enabled (to observe deny-rule hits)
resource "google_compute_firewall" "deny_telnet" {
  name        = "${var.name_prefix}-deny-telnet"
  network     = google_compute_network.lab_vpc.name
  direction   = "INGRESS"
  priority    = 900
  target_tags = ["web-lab"]

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "tcp"
    ports    = ["23"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ---------------------------------------------------------------------------
# Intentionally Misconfigured Static Route (for Network Analyzer)
# Points 192.168.50.0/24 to lab_vm, which has can_ip_forward = false.
# Network Analyzer evaluates configuration updates within ~10 minutes and
# surfaces ROUTE_NEXT_HOP_VM_IP_FORWARDING_DISABLED under
# google.networkanalyzer.vpcnetwork.connectivityInsight.
# ---------------------------------------------------------------------------
resource "google_compute_route" "broken_next_hop_route" {
  name                   = "${var.name_prefix}-broken-route"
  network                = google_compute_network.lab_vpc.name
  dest_range             = "192.168.50.0/24"
  priority               = 1000
  next_hop_instance      = google_compute_instance.lab_vm.name
  next_hop_instance_zone = var.zone
}
