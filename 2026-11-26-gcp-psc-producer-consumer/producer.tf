# -----------------------------------------------------------------------------
# PRODUCER PROJECT RESOURCES
# -----------------------------------------------------------------------------

resource "google_compute_network" "producer_vpc" {
  provider                = google.producer
  name                    = "psc-producer-vpc"
  auto_create_subnetworks = false
}

# Backend workload subnet (intentionally uses 10.10.1.0/24 — same CIDR as consumer VPC)
resource "google_compute_subnetwork" "producer_backend_subnet" {
  provider      = google.producer
  name          = "psc-producer-backend-subnet"
  region        = var.region
  network       = google_compute_network.producer_vpc.id
  ip_cidr_range = "10.10.1.0/24"
}

# Dedicated Private Service Connect NAT subnet (purpose = PRIVATE_SERVICE_CONNECT)
# A /28 provides 12 usable NAT IPs (4 reserved/unusable IPs per Google Cloud docs).
resource "google_compute_subnetwork" "producer_psc_nat_subnet" {
  provider      = google.producer
  name          = "psc-producer-nat-subnet"
  region        = var.region
  network       = google_compute_network.producer_vpc.id
  ip_cidr_range = "10.10.2.0/28"
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# Allow Google Cloud health check probes to reach the backend VM on TCP/80
resource "google_compute_firewall" "producer_allow_hc" {
  provider      = google.producer
  name          = "psc-producer-allow-hc"
  network       = google_compute_network.producer_vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["psc-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Allow SNATed consumer traffic arriving from the Producer PSC NAT subnet
resource "google_compute_firewall" "producer_allow_psc_nat" {
  provider      = google.producer
  name          = "psc-producer-allow-psc-nat"
  network       = google_compute_network.producer_vpc.name
  direction     = "INGRESS"
  source_ranges = [google_compute_subnetwork.producer_psc_nat_subnet.ip_cidr_range]
  target_tags   = ["psc-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Allow IAP SSH for administrative verification on the producer VM
resource "google_compute_firewall" "producer_allow_iap_ssh" {
  provider      = google.producer
  name          = "psc-producer-allow-iap-ssh"
  network       = google_compute_network.producer_vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["psc-backend"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Sample producer backend VM serving a lightweight HTTP response on port 80
resource "google_compute_instance" "producer_backend_vm" {
  provider     = google.producer
  name         = "psc-producer-backend-1"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["psc-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.producer_backend_subnet.id
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3
    cat <<'PY' > /opt/server.py
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import socket

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = (
                f"PSC Producer Backend OK\n"
                f"Host: {socket.gethostname()}\n"
                f"Client Source IP (Producer View): {self.client_address[0]}\n"
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
    PY
    nohup python3 /opt/server.py >/var/log/psc-server.log 2>&1 &
  EOT
}

resource "google_compute_instance_group" "producer_ig" {
  provider  = google.producer
  name      = "psc-producer-ig"
  zone      = var.zone
  instances = [google_compute_instance.producer_backend_vm.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_region_health_check" "producer_hc" {
  provider = google.producer
  name     = "psc-producer-hc"
  region   = var.region

  tcp_health_check {
    port = 80
  }
}

# Internal passthrough Network Load Balancer backend service
resource "google_compute_region_backend_service" "producer_ilb_backend" {
  provider              = google.producer
  name                  = "psc-producer-ilb-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.producer_hc.id]

  backend {
    group = google_compute_instance_group.producer_ig.id
  }
}

# Producer ILB forwarding rule (target of the Service Attachment)
resource "google_compute_forwarding_rule" "producer_ilb_fr" {
  provider              = google.producer
  name                  = "psc-producer-ilb-fr"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.producer_ilb_backend.id
  ports                 = ["80"]
  network               = google_compute_network.producer_vpc.id
  subnetwork            = google_compute_subnetwork.producer_backend_subnet.id
}

# Private Service Connect Service Attachment publishing the producer ILB
resource "google_compute_service_attachment" "producer_sa" {
  provider              = google.producer
  name                  = "psc-producer-sa"
  region                = var.region
  description           = "Published internal HTTP service for PSC producer-consumer lab"
  enable_proxy_protocol = var.enable_proxy_protocol
  connection_preference = var.connection_preference
  reconcile_connections = var.reconcile_connections
  nat_subnets           = [google_compute_subnetwork.producer_psc_nat_subnet.id]
  target_service        = google_compute_forwarding_rule.producer_ilb_fr.id
  domain_names          = [var.service_domain_name]

  dynamic "consumer_accept_lists" {
    for_each = (var.connection_preference == "ACCEPT_MANUAL" && var.accept_consumer_project && !var.reject_consumer_project) ? [1] : []
    content {
      project_id_or_num = var.consumer_project_id
      connection_limit  = var.consumer_connection_limit
    }
  }

  consumer_reject_lists = var.reject_consumer_project ? [var.consumer_project_id] : []
}
