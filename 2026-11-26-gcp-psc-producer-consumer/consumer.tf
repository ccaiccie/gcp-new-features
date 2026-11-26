# -----------------------------------------------------------------------------
# CONSUMER PROJECT RESOURCES
# -----------------------------------------------------------------------------

resource "google_compute_network" "consumer_vpc" {
  provider                = google.consumer
  name                    = "psc-consumer-vpc"
  auto_create_subnetworks = false
}

# Consumer subnet intentionally reuses 10.10.1.0/24 to prove zero IP-overlap conflict
resource "google_compute_subnetwork" "consumer_subnet" {
  provider      = google.consumer
  name          = "psc-consumer-subnet"
  region        = var.region
  network       = google_compute_network.consumer_vpc.id
  ip_cidr_range = "10.10.1.0/24"
}

# Allow IAP SSH to the consumer test VM
resource "google_compute_firewall" "consumer_allow_iap_ssh" {
  provider      = google.consumer
  name          = "psc-consumer-allow-iap-ssh"
  network       = google_compute_network.consumer_vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["psc-client"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Static internal IP address inside the consumer subnet for the PSC endpoint
resource "google_compute_address" "consumer_psc_ip" {
  provider     = google.consumer
  name         = "psc-consumer-endpoint-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.consumer_subnet.id
  address_type = "INTERNAL"
  address      = "10.10.1.50"
}

# Private Service Connect Consumer Endpoint (Forwarding Rule targeting the Service Attachment)
# Note: load_balancing_scheme must be "" (empty string) for PSC endpoints targeting published services.
resource "google_compute_forwarding_rule" "consumer_psc_endpoint" {
  provider              = google.consumer
  name                  = "psc-consumer-endpoint"
  region                = var.region
  network               = google_compute_network.consumer_vpc.id
  ip_address            = google_compute_address.consumer_psc_ip.id
  target                = google_compute_service_attachment.producer_sa.id
  load_balancing_scheme = ""

  depends_on = [google_compute_service_attachment.producer_sa]
}

# Explicit Cloud DNS Private Zone in the consumer VPC mapping an FQDN to the PSC endpoint IP
resource "google_dns_managed_zone" "consumer_private_dns" {
  provider    = google.consumer
  name        = "psc-lab-private-zone"
  dns_name    = var.manual_dns_zone_domain
  description = "Private DNS zone for resolving the PSC published service endpoint"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.consumer_vpc.id
    }
  }
}

resource "google_dns_record_set" "consumer_service_a_record" {
  provider     = google.consumer
  name         = "app.${var.manual_dns_zone_domain}"
  managed_zone = google_dns_managed_zone.consumer_private_dns.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.consumer_psc_ip.address]
}

# Consumer test VM inside the consumer VPC (no public IP needed; connect via IAP)
resource "google_compute_instance" "consumer_client_vm" {
  provider     = google.consumer
  name         = "psc-consumer-client-1"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["psc-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.consumer_subnet.id
  }
}
