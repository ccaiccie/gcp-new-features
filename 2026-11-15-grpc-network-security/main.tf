resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-net"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.lab.id
  stack_type    = "IPV4_ONLY"
}

# Health checks and the Application Load Balancer proxy reach the MIG on 9000.
resource "google_compute_firewall" "lb_to_backends" {
  name    = "${var.name_prefix}-lb-to-backends"
  network = google_compute_network.lab.id
  allow {
    protocol = "tcp"
    ports    = ["9000"]
  }
  source_ranges = ["130.211.0.0/16", "35.191.0.0/16"]
  target_tags   = ["grpc-lab"]
}

data "google_compute_image" "cos" {
  family  = "cos-stable"
  project = "cos-cloud"
}

resource "google_compute_instance_template" "lab" {
  name_prefix  = "${var.name_prefix}-tmpl-"
  machine_type = var.machine_type
  tags         = ["grpc-lab"]
  region       = var.region

  disk {
    source_image = data.google_compute_image.cos.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
  }

  metadata = {
    gce-container-declaration = yamlencode({
      spec = {
        containers = [{
          name  = "grpcbin"
          image = var.grpc_image
          ports = [{
            containerPort = 9000
            hostPort      = 9000
          }]
        }]
        restartPolicy = "Always"
      }
    })
    google-logging-enabled = "true"
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "lab" {
  name               = "${var.name_prefix}-mig"
  base_instance_name = var.name_prefix
  zone               = var.zone
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.lab.id
  }

  named_port {
    name = "grpc"
    port = 9000
  }
}

# The sample image is a gRPC test server and may not implement grpc.health.v1.Health.
# A TCP check confirms the listener is open. In production, implement Health and
# switch this resource to a grpc {} block that expects SERVING.
resource "google_compute_health_check" "lab" {
  name               = "${var.name_prefix}-tcp-9000"
  timeout_sec        = 5
  check_interval_sec = 10

  tcp_health_check {
    port = 9000
  }
}

resource "google_compute_security_policy" "lab" {
  name        = "${var.name_prefix}-armor"
  description = "Example Cloud Armor policy for the gRPC lab. Tighten the default allow before any real use."

  # Documentation-only deny (TEST-NET-1). Replace or extend with your own ranges.
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["192.0.2.1/32"]
      }
    }
    description = "Example deny for 192.0.2.1/32 (TEST-NET-1)."
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow. Change to deny and add an allow list for a tighter lab."
  }
}

resource "google_compute_backend_service" "lab" {
  name                  = "${var.name_prefix}-backend"
  protocol              = "H2C"
  port_name             = "grpc"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.lab.id]
  security_policy       = google_compute_security_policy.lab.id

  backend {
    group           = google_compute_instance_group_manager.lab.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "lab" {
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.lab.id
}

resource "tls_private_key" "lab" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "lab" {
  private_key_pem       = tls_private_key.lab.private_key_pem
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  dns_names = ["grpc-lab.example.com"]

  subject {
    common_name = "grpc-lab.example.com"
  }
}

resource "google_compute_ssl_certificate" "lab" {
  name_prefix = "${var.name_prefix}-cert-"
  private_key = tls_private_key.lab.private_key_pem
  certificate = tls_self_signed_cert.lab.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "lab" {
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.lab.id
  ssl_certificates = [google_compute_ssl_certificate.lab.id]
}

resource "google_compute_global_address" "lab" {
  name = "${var.name_prefix}-ip"
}

resource "google_compute_global_forwarding_rule" "lab" {
  name                  = "${var.name_prefix}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"
  ip_address            = google_compute_global_address.lab.address
  target                = google_compute_target_https_proxy.lab.id
}
