# ------------------------------------------------------------------------------
# Part 1: VPC, Simple Nginx Backend VM, Health Check & Global External ALB
# ------------------------------------------------------------------------------

resource "google_compute_network" "lab_vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "backend" {
  name          = "${var.prefix}-subnet"
  ip_cidr_range = "10.80.1.0/24"
  region        = var.region
  network       = google_compute_network.lab_vpc.id
}

# Allow Google Cloud Load Balancer & Health Check probes to reach backend TCP 80
resource "google_compute_firewall" "allow_lb_hc" {
  name    = "${var.prefix}-allow-lb-hc"
  network = google_compute_network.lab_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["armor-lab-backend"]
}

resource "google_compute_instance" "backend_vm" {
  name         = "${var.prefix}-backend"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["armor-lab-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.backend.id
    access_config {} # Ephemeral IP solely for apt-get nginx during lab startup
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx
    cat <<'NGINX' > /etc/nginx/sites-available/default
    server {
      listen 80 default_server;
      location / {
        default_type application/json;
        return 200 '{"status":"allowed","backend":"cloud-armor-cel-lab"}\n';
      }
    }
    NGINX
    systemctl restart nginx
  EOF
}

resource "google_compute_instance_group" "backend_ig" {
  name      = "${var.prefix}-ig"
  zone      = var.zone
  instances = [google_compute_instance.backend_vm.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "http" {
  name = "${var.prefix}-hc"

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# ------------------------------------------------------------------------------
# Part 2: Cloud Armor Security Policy (CEL Body/Params + Adaptive Protection)
# ------------------------------------------------------------------------------

resource "google_compute_security_policy" "armor_policy" {
  name        = "${var.prefix}-policy"
  description = "Custom CEL request.params & request.body rules + Adaptive Protection"

  advanced_options_config {
    log_level    = "VERBOSE"
    json_parsing = "STANDARD"
  }

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  # Rule 1000: Inspect parsed JSON / form / query parameter via request.params
  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Deny requests where password parameter contains 123"
    match {
      expr {
        expression = "has(request.params.password) && request.params.password.contains('123')"
      }
    }
  }

  # Rule 1100: Inspect raw HTTP POST body via request.body
  rule {
    action      = "deny(403)"
    priority    = 1100
    description = "Deny POST requests containing malicious-value in raw request.body"
    match {
      expr {
        expression = "request.method == 'POST' && request.body.contains('malicious-value')"
      }
    }
  }

  # Default rule: allow remaining requests
  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow rule"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Global External Application Load Balancer wiring
resource "google_compute_backend_service" "backend" {
  name                  = "${var.prefix}-backend-svc"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.http.id]
  security_policy       = google_compute_security_policy.armor_policy.id

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  backend {
    group = google_compute_instance_group.backend_ig.id
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "${var.prefix}-url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.prefix}-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_address" "lb_ip" {
  name = "${var.prefix}-ip"
}

resource "google_compute_global_forwarding_rule" "http_fwd" {
  name                  = "${var.prefix}-fwd-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}
