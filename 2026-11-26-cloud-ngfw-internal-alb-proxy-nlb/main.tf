terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.10.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  alb_forwarding_rule_ref = "projects/${var.project_id}/regions/${var.region}/forwardingRules/${google_compute_forwarding_rule.internal_alb.name}"
}

# ------------------------------------------------------------------------------
# 1. VPC & Subnets (including the REGIONAL_MANAGED_PROXY proxy-only subnet)
# ------------------------------------------------------------------------------
resource "google_compute_network" "lab_vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "proxy_only" {
  name          = "${var.name_prefix}-proxy-only"
  ip_cidr_range = var.proxy_only_cidr
  region        = var.region
  network       = google_compute_network.lab_vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_subnetwork" "backend" {
  name          = "${var.name_prefix}-backend-subnet"
  ip_cidr_range = var.backend_subnet_cidr
  region        = var.region
  network       = google_compute_network.lab_vpc.id
}

resource "google_compute_subnetwork" "client" {
  name          = "${var.name_prefix}-client-subnet"
  ip_cidr_range = var.client_subnet_cidr
  region        = var.region
  network       = google_compute_network.lab_vpc.id
}

# ------------------------------------------------------------------------------
# 2. Backend VM & Instance Group
# ------------------------------------------------------------------------------
resource "google_compute_instance" "backend_vm" {
  name         = "${var.name_prefix}-backend-1"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["ilb-backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.backend.id
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3
    cat <<'PY' > /tmp/server.py
    import http.server, socketserver, socket

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            body = f"OK from {socket.gethostname()} via Internal LB\n".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    with socketserver.TCPServer(("0.0.0.0", 80), Handler) as httpd:
        httpd.serve_forever()
    PY
    nohup python3 /tmp/server.py >/var/log/demo-http.log 2>&1 &
  EOT
}

resource "google_compute_instance_group" "backend_ig" {
  name      = "${var.name_prefix}-backend-ig"
  zone      = var.zone
  instances = [google_compute_instance.backend_vm.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

# ------------------------------------------------------------------------------
# 3. Regional Internal Application Load Balancer (Envoy-based)
# ------------------------------------------------------------------------------
resource "google_compute_region_health_check" "http_hc" {
  name   = "${var.name_prefix}-http-hc"
  region = var.region

  http_health_check {
    port = 80
  }
}

resource "google_compute_region_backend_service" "alb_backend" {
  name                  = "${var.name_prefix}-alb-backend"
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
}

resource "google_compute_region_url_map" "alb_url_map" {
  name            = "${var.name_prefix}-alb-url-map"
  region          = var.region
  default_service = google_compute_region_backend_service.alb_backend.id
}

resource "google_compute_region_target_http_proxy" "alb_proxy" {
  name    = "${var.name_prefix}-alb-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.alb_url_map.id
}

resource "google_compute_forwarding_rule" "internal_alb" {
  name                  = "${var.name_prefix}-alb-fr"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.alb_proxy.id
  network               = google_compute_network.lab_vpc.id
  subnetwork            = google_compute_subnetwork.backend.id
  network_tier          = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only]
}

# ------------------------------------------------------------------------------
# 4. Optional: Regional Internal Proxy Network Load Balancer (TCP 8080 -> 80)
# ------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "nlb_backend" {
  count                 = var.enable_proxy_nlb ? 1 : 0
  name                  = "${var.name_prefix}-nlb-backend"
  region                = var.region
  protocol              = "TCP"
  port_name             = "http"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.http_hc.id]

  backend {
    group           = google_compute_instance_group.backend_ig.id
    balancing_mode  = "CONNECTION"
    max_connections = 100
  }
}

resource "google_compute_region_target_tcp_proxy" "nlb_proxy" {
  count           = var.enable_proxy_nlb ? 1 : 0
  name            = "${var.name_prefix}-nlb-tcp-proxy"
  region          = var.region
  backend_service = google_compute_region_backend_service.nlb_backend[0].id
}

resource "google_compute_forwarding_rule" "internal_proxy_nlb" {
  count                 = var.enable_proxy_nlb ? 1 : 0
  name                  = "${var.name_prefix}-nlb-fr"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "8080"
  target                = google_compute_region_target_tcp_proxy.nlb_proxy[0].id
  network               = google_compute_network.lab_vpc.id
  subnetwork            = google_compute_subnetwork.backend.id
  network_tier          = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only]
}

# ------------------------------------------------------------------------------
# 5. Two Client Test VMs (Approved vs Blocked)
# ------------------------------------------------------------------------------
resource "google_compute_instance" "client_allowed" {
  name         = "client-allowed"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["lab-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.client.id
  }
}

resource "google_compute_instance" "client_blocked" {
  name         = "client-blocked"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["lab-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.client.id
  }
}

# ------------------------------------------------------------------------------
# 6. Backend VM & Management Firewall Rules (Layer A: INSTANCES)
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_proxy_and_hc_to_backends" {
  name          = "${var.name_prefix}-allow-proxy-hc-backends"
  network       = google_compute_network.lab_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.proxy_only_cidr, "35.191.0.0/16"]
  target_tags   = ["ilb-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.lab_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ------------------------------------------------------------------------------
# 7. Cloud NGFW Regional Network Firewall Policy (Layer B: INTERNAL_MANAGED_LB)
# ------------------------------------------------------------------------------
resource "google_compute_region_network_firewall_policy" "ilb_policy" {
  name        = "${var.name_prefix}-ilb-policy"
  region      = var.region
  description = "Protect managed Envoy proxies for internal ALB and internal proxy NLB"
}

resource "google_compute_region_network_firewall_policy_association" "ilb_policy_assoc" {
  name              = "${var.name_prefix}-ilb-policy-assoc"
  region            = var.region
  attachment_target = google_compute_network.lab_vpc.id
  firewall_policy   = google_compute_region_network_firewall_policy.ilb_policy.name
}

# Rule 900: Allow Google managed Envoy frontend health-check probes (IPv4)
resource "google_compute_region_network_firewall_policy_rule" "allow_envoy_hc_probes" {
  firewall_policy = google_compute_region_network_firewall_policy.ilb_policy.name
  region          = var.region
  rule_name       = "allow-envoy-frontend-hc-probes"
  priority        = 900
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = true

  target_type = "INTERNAL_MANAGED_LB"
  target_forwarding_rules = var.scope_to_single_forwarding_rule ? [
    local.alb_forwarding_rule_ref
  ] : null

  match {
    src_ip_ranges = ["35.191.0.0/16"]
    layer4_configs {
      ip_protocol = "tcp"
      # Destination ports MUST be omitted for INTERNAL_MANAGED_LB
    }
  }
}

# Rule 1000: Allow the approved client VM IP
resource "google_compute_region_network_firewall_policy_rule" "allow_approved_client" {
  firewall_policy = google_compute_region_network_firewall_policy.ilb_policy.name
  region          = var.region
  rule_name       = "allow-approved-client"
  priority        = 1000
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = true

  target_type = "INTERNAL_MANAGED_LB"
  target_forwarding_rules = var.scope_to_single_forwarding_rule ? [
    local.alb_forwarding_rule_ref
  ] : null

  match {
    src_ip_ranges = ["${google_compute_instance.client_allowed.network_interface[0].network_ip}/32"]
    layer4_configs {
      ip_protocol = "tcp"
    }
  }
}

# Rule 2000: Explicit baseline DENY all other ingress (Envoy proxies default to ALLOW!)
resource "google_compute_region_network_firewall_policy_rule" "deny_all_other_ingress" {
  firewall_policy = google_compute_region_network_firewall_policy.ilb_policy.name
  region          = var.region
  rule_name       = "deny-all-other-ilb-ingress"
  priority        = 2000
  direction       = "INGRESS"
  action          = "deny"
  enable_logging  = true

  target_type = "INTERNAL_MANAGED_LB"
  target_forwarding_rules = var.scope_to_single_forwarding_rule ? [
    local.alb_forwarding_rule_ref
  ] : null

  match {
    src_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "tcp"
    }
  }
}
