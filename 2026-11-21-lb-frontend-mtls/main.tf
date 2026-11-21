locals {
  apis = [
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
    "networksecurity.googleapis.com",
    "networkservices.googleapis.com",
  ]
  # Custom request headers the load balancer adds after mTLS validation.
  # Limit: 16 custom request headers (8 KB) per backend service.
  mtls_headers = [
    "X-Client-Cert-Present:{client_cert_present}",
    "X-Client-Cert-Chain-Verified:{client_cert_chain_verified}",
    "X-Client-Cert-Error:{client_cert_error}",
    "X-Client-Cert-Hash:{client_cert_sha256_fingerprint}",
    "X-Client-Cert-Serial-Number:{client_cert_serial_number}",
    "X-Client-Cert-SPIFFE:{client_cert_spiffe_id}",
    "X-Client-Cert-Valid-Not-After:{client_cert_valid_not_after}",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------- network and backend ----------
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.60.0.0/24"
}

# Google Front End and health check ranges reach the backend on 8080
resource "google_compute_firewall" "allow_lb" {
  name          = "${var.name_prefix}-allow-lb-hc"
  network       = google_compute_network.vpc.id
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["mtls-backend"]
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.vpc.id
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["mtls-backend"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# A tiny backend that echoes the request headers it receives, so you can
# see exactly what the load balancer adds after client certificate validation.
resource "google_compute_instance" "echo" {
  name         = "${var.name_prefix}-echo"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["mtls-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    # No external IP: traffic arrives only through the load balancer.
  }

  metadata_startup_script = file("${path.module}/scripts/echo-server-startup.sh")

  shielded_instance_config {
    enable_secure_boot = true
  }
}

resource "google_compute_instance_group" "echo" {
  name      = "${var.name_prefix}-echo-ig"
  zone      = var.zone
  instances = [google_compute_instance.echo.self_link]
  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_health_check" "echo" {
  name = "${var.name_prefix}-hc"
  http_health_check {
    port         = 8080
    request_path = "/healthz"
  }
}

resource "google_compute_backend_service" "echo" {
  name                  = "${var.name_prefix}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  health_checks         = [google_compute_health_check.echo.id]
  custom_request_headers = local.mtls_headers

  backend {
    group = google_compute_instance_group.echo.self_link
  }

  # Logs record mTLS validation failures (for example client_cert_not_provided)
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "lb" {
  name            = "${var.name_prefix}-urlmap"
  default_service = google_compute_backend_service.echo.id
}

# ---------- mTLS: trust config -> ServerTlsPolicy -> target HTTPS proxy ----------
resource "google_certificate_manager_trust_config" "lab" {
  name        = "${var.name_prefix}-trust-config"
  location    = "global"
  description = "Lab root CA as trust anchor, lab issuing CA as intermediate"

  trust_stores {
    trust_anchors {
      pem_certificate = tls_self_signed_cert.root.cert_pem
    }
    intermediate_cas {
      pem_certificate = tls_locally_signed_cert.intermediate.cert_pem
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_network_security_server_tls_policy" "mtls" {
  name     = "${var.name_prefix}-client-auth"
  location = "global"

  mtls_policy {
    client_validation_mode         = var.client_validation_mode
    client_validation_trust_config = google_certificate_manager_trust_config.lab.id
    client_validation_relaxations  = var.client_validation_mode == "ALLOW_VALIDATION_RELAXATIONS" ? var.client_validation_relaxations : null
  }

  lifecycle {
    precondition {
      condition     = var.client_validation_mode != "ALLOW_VALIDATION_RELAXATIONS" || length(var.client_validation_relaxations) > 0
      error_message = "ALLOW_VALIDATION_RELAXATIONS needs at least one relaxation in client_validation_relaxations."
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_ssl_certificate" "server" {
  name        = "${var.name_prefix}-server-cert"
  certificate = tls_self_signed_cert.server.cert_pem
  private_key = tls_private_key.server.private_key_pem
  depends_on  = [google_project_service.apis]
}

resource "google_compute_target_https_proxy" "lb" {
  name              = "${var.name_prefix}-https-proxy"
  url_map           = google_compute_url_map.lb.id
  ssl_certificates  = [google_compute_ssl_certificate.server.id]
  server_tls_policy = google_network_security_server_tls_policy.mtls.id
}

resource "google_compute_global_address" "lb" {
  name       = "${var.name_prefix}-ip"
  depends_on = [google_project_service.apis]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.lb.id
}
