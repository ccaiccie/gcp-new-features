# Regional Internal Application Load Balancer (INTERNAL_MANAGED)
# Practice lab for GCP Load Balancing DENY_BY_DEFAULT Authorization Policies.

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = "${var.prefix}-app-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "proxy_only" {
  name          = "${var.prefix}-proxy-only"
  ip_cidr_range = "10.10.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_firewall" "allow_hc_and_proxy" {
  name    = "${var.prefix}-allow-hc-proxy"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "10.10.2.0/24",
  ]
  target_tags = ["${var.prefix}-backend"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.prefix}-allow-iap-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.prefix}-client", "${var.prefix}-backend"]
}

resource "google_service_account" "client_sa" {
  account_id   = "${var.prefix}-client-sa"
  display_name = "AuthzPolicy Lab Client Service Account"
}

resource "google_compute_instance" "backend_vm" {
  name         = "${var.prefix}-backend"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["${var.prefix}-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app_subnet.id
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    cat <<'PY' > /opt/server.py
    from http.server import BaseHTTPRequestHandler, HTTPServer
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"OK from backend path={self.path}\n".encode())
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
    PY
    nohup python3 /opt/server.py >/var/log/backend.log 2>&1 &
  EOT

  depends_on = [google_project_service.required]
}

resource "google_compute_instance" "client_vm" {
  name         = "${var.prefix}-client"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["${var.prefix}-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app_subnet.id
  }

  service_account {
    email  = google_service_account.client_sa.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.required]
}

resource "google_compute_instance_group" "backend_ig" {
  name      = "${var.prefix}-backend-ig"
  zone      = var.zone
  instances = [google_compute_instance.backend_vm.self_link]

  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_region_health_check" "http_hc" {
  name   = "${var.prefix}-hc"
  region = var.region

  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_region_backend_service" "backend" {
  name                  = "${var.prefix}-backend-svc"
  region                = var.region
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.http_hc.id]

  backend {
    group           = google_compute_instance_group.backend_ig.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_region_url_map" "url_map" {
  name            = "${var.prefix}-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.backend.id
}

resource "google_compute_region_target_http_proxy" "proxy" {
  name    = "${var.prefix}-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.url_map.id
}

resource "google_compute_forwarding_rule" "ilb_fr" {
  name                  = "${var.prefix}-ilb-fr"
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "80"
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.app_subnet.id
  target                = google_compute_region_target_http_proxy.proxy.id
  depends_on            = [google_compute_subnetwork.proxy_only]
}
