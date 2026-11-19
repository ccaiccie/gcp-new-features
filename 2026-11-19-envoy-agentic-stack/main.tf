# Lab network. CIDRs are examples for this exercise, not from the source post.
resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.lab.id
}

# Google health-check ranges for the global external Application Load Balancer.
resource "google_compute_firewall" "lb_health" {
  name          = "${var.name_prefix}-allow-lb-health"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["lab-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Optional IAP SSH for troubleshooting. The VMs have no public IP.
resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["lab-backend"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

locals {
  backends = {
    model = {
      ip      = var.model_ip
      message = "model-standin: URI path /v1/* reached this backend. This is path routing, not body-based model routing."
    }
    mcp = {
      ip      = var.mcp_ip
      message = "mcp-standin: URI path /mcp* reached this backend. This is path routing, not MCP Method/Name header routing."
    }
  }
}

resource "google_compute_instance" "backend" {
  for_each     = local.backends
  name         = "${var.name_prefix}-${each.key}"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["lab-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    network_ip = each.value.ip
  }

  # Debian ships python3, so no package download is needed.
  metadata_startup_script = <<-EOT
    mkdir -p /srv/www
    printf '%s\n' '${each.value.message}' > /srv/www/index.html
    cd /srv/www && nohup python3 -m http.server 80 >/var/log/backend-http.log 2>&1 &
  EOT

  shielded_instance_config {
    enable_secure_boot = true
  }
}

resource "google_compute_instance_group" "backend" {
  for_each  = local.backends
  name      = "${var.name_prefix}-${each.key}-ig"
  zone      = var.zone
  network   = google_compute_network.lab.id
  instances = [google_compute_instance.backend[each.key].self_link]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "http" {
  name               = "${var.name_prefix}-http-hc"
  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Request-count rate limit. This is NOT token-aware TPM/TPD.
resource "google_compute_security_policy" "request_rate" {
  name        = "${var.name_prefix}-request-rate"
  type        = "CLOUD_ARMOR"
  description = "Lab stand-in: request-count throttle with HTTP 429. Not token-aware."

  rule {
    action   = "throttle"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_count
        interval_sec = var.rate_limit_interval_sec
      }
    }
    description = "Request-count throttle per source IP, deny with 429 when exceeded."
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
    description = "Default allow"
  }
}

resource "google_compute_backend_service" "backend" {
  for_each              = local.backends
  name                  = "${var.name_prefix}-${each.key}-bes"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  security_policy       = google_compute_security_policy.request_rate.id
  health_checks         = [google_compute_health_check.http.id]

  backend {
    group           = google_compute_instance_group.backend[each.key].self_link
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

# Path-based URL map: /mcp* to the MCP stand-in, everything else (including /v1*) to the model stand-in.
# This is classic Layer 7 URI routing, used here to contrast with body-based model routing and
# Mcp-Method / Mcp-Name routing, which the provider does not expose.
resource "google_compute_url_map" "lab" {
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.backend["model"].id

  host_rule {
    hosts        = ["*"]
    path_matcher = "ai"
  }

  path_matcher {
    name            = "ai"
    default_service = google_compute_backend_service.backend["model"].id

    path_rule {
      paths   = ["/mcp", "/mcp/*"]
      service = google_compute_backend_service.backend["mcp"].id
    }

    path_rule {
      paths   = ["/v1", "/v1/*"]
      service = google_compute_backend_service.backend["model"].id
    }
  }
}

resource "google_compute_target_http_proxy" "lab" {
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.lab.id
}

resource "google_compute_global_address" "lab" {
  name         = "${var.name_prefix}-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "lab" {
  name                  = "${var.name_prefix}-fr"
  ip_address            = google_compute_global_address.lab.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.lab.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
