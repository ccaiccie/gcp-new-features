# ------------------------------------------------------------------------------
# Part 1: Custom VPC, Subnets (PGA Enabled vs Disabled), Routes, Firewall & VM
# ------------------------------------------------------------------------------

resource "google_compute_network" "lab_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "pga_enabled" {
  name                     = "pga-enabled-subnet"
  ip_cidr_range            = "10.50.1.0/24"
  region                   = var.region
  network                  = google_compute_network.lab_vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "pga_disabled" {
  name                     = "pga-disabled-subnet"
  ip_cidr_range            = "10.50.2.0/24"
  region                   = var.region
  network                  = google_compute_network.lab_vpc.id
  private_ip_google_access = false
}

# Custom static routes via default-internet-gateway for private.googleapis.com VIP
# and direct connectivity range (34.126.0.0/18)
resource "google_compute_route" "pga_private_vip" {
  name             = "${var.vpc_name}-pga-private-vip"
  network          = google_compute_network.lab_vpc.name
  dest_range       = "199.36.153.8/30"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_route" "pga_direct_connectivity" {
  name             = "${var.vpc_name}-pga-direct-conn"
  network          = google_compute_network.lab_vpc.name
  dest_range       = "34.126.0.0/18"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# Allow IAP TCP forwarding for SSH to the private VM (no external IP)
resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "${var.vpc_name}-allow-iap-ssh"
  network   = google_compute_network.lab_vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["private-api-test"]
}

# Explicit egress allow rule for PGA VIP, direct connectivity, and PSC endpoint
resource "google_compute_firewall" "allow_google_apis_egress" {
  name      = "${var.vpc_name}-allow-google-apis"
  network   = google_compute_network.lab_vpc.name
  direction = "EGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  destination_ranges = [
    "199.36.153.8/30",
    "34.126.0.0/18",
    "${var.psc_endpoint_ip}/32",
  ]
  target_tags = ["private-api-test"]
}

# Private DNS zone for private.googleapis.com (PGA VIP option)
resource "google_dns_managed_zone" "pga_googleapis" {
  name        = "pga-googleapis-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS zone for Private Google Access (private.googleapis.com)"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.lab_vpc.id
    }
  }
}

resource "google_dns_record_set" "pga_private_a" {
  name         = "private.googleapis.com."
  managed_zone = google_dns_managed_zone.pga_googleapis.name
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}

resource "google_dns_record_set" "pga_wildcard_cname" {
  name         = "*.googleapis.com."
  managed_zone = google_dns_managed_zone.pga_googleapis.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["private.googleapis.com."]
}

# Private VM (no access_config => no external IP address)
resource "google_compute_instance" "test_vm" {
  name         = "pga-psc-test-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["private-api-test"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.pga_enabled.id
    # Intentionally omitted: access_config {} (VM has internal IP only)
  }

  shielded_instance_config {
    enable_secure_boot = true
  }
}

# ------------------------------------------------------------------------------
# Part 2: Private Service Connect Endpoint for Google APIs + Private DNS
# ------------------------------------------------------------------------------

resource "google_compute_global_address" "psc_api_ip" {
  name         = "${var.psc_endpoint_name}-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.lab_vpc.id
  address      = var.psc_endpoint_ip
}

resource "google_compute_global_forwarding_rule" "psc_api_endpoint" {
  name                  = var.psc_endpoint_name
  target                = var.psc_api_bundle
  network               = google_compute_network.lab_vpc.id
  ip_address            = google_compute_global_address.psc_api_ip.id
  load_balancing_scheme = ""
}

# Private DNS zone for p.googleapis.com pointing storage-<endpoint>.p.googleapis.com to PSC IP
resource "google_dns_managed_zone" "psc_p_googleapis" {
  name        = "psc-p-googleapis-zone"
  dns_name    = "p.googleapis.com."
  description = "Private DNS zone for PSC endpoint for Google APIs"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.lab_vpc.id
    }
  }
}

resource "google_dns_record_set" "psc_storage_a" {
  name         = "storage-${var.psc_endpoint_name}.p.googleapis.com."
  managed_zone = google_dns_managed_zone.psc_p_googleapis.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc_api_ip.address]
}
