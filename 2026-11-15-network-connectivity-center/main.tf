resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "networkconnectivity" {
  project            = var.project_id
  service            = "networkconnectivity.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "center" {
  name                    = "${var.network_prefix}-center"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_network" "edge_a" {
  name                    = "${var.network_prefix}-edge-a"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_network" "edge_b" {
  name                    = "${var.network_prefix}-edge-b"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "center" {
  name          = "${var.network_prefix}-center"
  ip_cidr_range = var.center_cidr
  region        = var.region
  network       = google_compute_network.center.id
  stack_type    = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "edge_a" {
  name          = "${var.network_prefix}-edge-a"
  ip_cidr_range = var.edge_a_cidr
  region        = var.region
  network       = google_compute_network.edge_a.id
  stack_type    = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "edge_b" {
  name          = "${var.network_prefix}-edge-b"
  ip_cidr_range = var.edge_b_cidr
  region        = var.region
  network       = google_compute_network.edge_b.id
  stack_type    = "IPV4_ONLY"
}

# Allow IAP SSH and ICMP plus internal TCP/UDP among the three lab CIDRs.
# Edge-to-edge pings still fail under star topology because the hub
# does not install east-west routes in the edge group.
locals {
  lab_cidrs = [var.center_cidr, var.edge_a_cidr, var.edge_b_cidr]
  networks = {
    center = google_compute_network.center.id
    edge_a = google_compute_network.edge_a.id
    edge_b = google_compute_network.edge_b.id
  }
}

resource "google_compute_firewall" "iap_ssh" {
  for_each = local.networks

  name    = "${var.network_prefix}-iap-ssh-${each.key}"
  network = each.value
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]
}

resource "google_compute_firewall" "internal" {
  for_each = local.networks

  name    = "${var.network_prefix}-internal-${each.key}"
  network = each.value
  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = local.lab_cidrs
}

resource "google_network_connectivity_hub" "lab" {
  name            = var.hub_name
  description     = "Star-topology lab hub for the Network Connectivity Center lesson."
  policy_mode     = "PRESET"
  preset_topology = "STAR"
  export_psc      = true

  depends_on = [google_project_service.networkconnectivity]
}

resource "google_network_connectivity_spoke" "center" {
  name        = "${var.network_prefix}-center"
  location    = "global"
  description = "Center-group VPC spoke."
  hub         = google_network_connectivity_hub.lab.id
  group       = "center"

  linked_vpc_network {
    uri = google_compute_network.center.self_link
  }
}

resource "google_network_connectivity_spoke" "edge_a" {
  name        = "${var.network_prefix}-edge-a"
  location    = "global"
  description = "Edge-group VPC spoke A."
  hub         = google_network_connectivity_hub.lab.id
  group       = "edge"

  linked_vpc_network {
    uri = google_compute_network.edge_a.self_link
  }
}

resource "google_network_connectivity_spoke" "edge_b" {
  name        = "${var.network_prefix}-edge-b"
  location    = "global"
  description = "Edge-group VPC spoke B."
  hub         = google_network_connectivity_hub.lab.id
  group       = "edge"

  linked_vpc_network {
    uri = google_compute_network.edge_b.self_link
  }
}

resource "google_compute_instance" "center" {
  name         = "${var.network_prefix}-center-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.center.id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_network_connectivity_spoke.center]
}

resource "google_compute_instance" "edge_a" {
  name         = "${var.network_prefix}-edge-a-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.edge_a.id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_network_connectivity_spoke.edge_a]
}

resource "google_compute_instance" "edge_b" {
  name         = "${var.network_prefix}-edge-b-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.edge_b.id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_network_connectivity_spoke.edge_b]
}
