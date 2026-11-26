# Google Cloud IAP (HTTPS Backend) + IAP TCP Forwarding (No Public IP VM) Lab
# Official docs:
#   https://cloud.google.com/iap/docs/using-tcp-forwarding
#   https://cloud.google.com/iap/docs/enabling-compute-howto

resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.prefix}-private-subnet"
  ip_cidr_range = "10.20.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Official IAP TCP forwarding IPv4 source range: 35.235.240.0/20
# Notice: No 0.0.0.0/0 default-allow-ssh or default-allow-rdp rule exists in this custom VPC.
resource "google_compute_firewall" "allow_iap_tcp" {
  name      = "${var.prefix}-allow-ingress-from-iap"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-tcp-target"]
}

# Private Compute Engine VM with NO external/public IP (no access_config block)
resource "google_compute_instance" "private_vm" {
  name         = "${var.prefix}-private-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["iap-tcp-target"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    # Intentionally omitted access_config -> internal IPv4 only on nic0
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

# Per-VM IAM binding for IAP TCP forwarding with destination.port == 22 CEL condition
resource "google_iap_tunnel_instance_iam_member" "ssh_tunnel_user" {
  project  = var.project_id
  zone     = var.zone
  instance = google_compute_instance.private_vm.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = var.user_member

  condition {
    title       = "allow-ssh-port-22-only"
    description = "Allow IAP TCP tunneling only to destination port 22."
    expression  = "destination.port == 22"
  }
}

# --- Part 2: IAP-Protected HTTPS Backend Service ---

resource "google_compute_instance_group" "web_ig" {
  name      = "${var.prefix}-web-ig"
  zone      = var.zone
  instances = [google_compute_instance.private_vm.id]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "http_hc" {
  name = "${var.prefix}-http-hc"
  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "iap_https_backend" {
  name                  = "${var.prefix}-iap-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.http_hc.id]

  backend {
    group = google_compute_instance_group.web_ig.id
  }

  iap {
    enabled = true
  }
}

# Grant IAP-secured Web App User on the HTTPS backend service
resource "google_iap_web_backend_service_iam_member" "https_app_user" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.iap_https_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = var.user_member
}
