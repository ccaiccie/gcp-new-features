locals {
  apis = ["compute.googleapis.com", "networkmanagement.googleapis.com"]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Custom-mode VPC with two subnets and two VMs without external addresses.
# ---------------------------------------------------------------------------
resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "a" {
  name          = "${var.name_prefix}-subnet-a"
  region        = var.region
  network       = google_compute_network.lab.id
  ip_cidr_range = var.subnet_a_cidr
}

resource "google_compute_subnetwork" "b" {
  name          = "${var.name_prefix}-subnet-b"
  region        = var.region
  network       = google_compute_network.lab.id
  ip_cidr_range = var.subnet_b_cidr
}

resource "google_compute_instance" "vm_a" {
  name         = "${var.name_prefix}-vm-a"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["app"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.a.id
  }
}

resource "google_compute_instance" "vm_b" {
  name         = "${var.name_prefix}-vm-b"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.b.id
  }
}

# Only the allowed port is opened. Anything else to VM B hits the implied deny ingress rule.
resource "google_compute_firewall" "allow_app_to_web" {
  name          = "${var.name_prefix}-allow-${var.allowed_port}"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [var.subnet_a_cidr]
  target_tags   = ["web"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.allowed_port)]
  }
}

# ---------------------------------------------------------------------------
# Connectivity Tests as code.
# ---------------------------------------------------------------------------
resource "google_network_management_connectivity_test" "allowed" {
  name        = "${var.name_prefix}-a-to-b-${var.allowed_port}"
  description = "Expected REACHABLE: firewall allows tcp/${var.allowed_port} from subnet A to tag web."
  protocol    = "TCP"
  round_trip  = true

  source {
    instance = google_compute_instance.vm_a.id
  }

  destination {
    instance = google_compute_instance.vm_b.id
    port     = var.allowed_port
  }

  depends_on = [google_compute_firewall.allow_app_to_web]
}

resource "google_network_management_connectivity_test" "blocked" {
  name        = "${var.name_prefix}-a-to-b-${var.blocked_port}"
  description = "Expected UNREACHABLE: no rule allows tcp/${var.blocked_port}, implied deny ingress drops it."
  protocol    = "TCP"

  source {
    instance = google_compute_instance.vm_a.id
  }

  destination {
    instance = google_compute_instance.vm_b.id
    port     = var.blocked_port
  }

  depends_on = [google_compute_firewall.allow_app_to_web]
}
