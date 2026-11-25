# ------------------------------------------------------------------------------
# VPC Network with ULA Internal IPv6 Enabled
# ------------------------------------------------------------------------------
resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  enable_ula_internal_ipv6 = true
}

# ------------------------------------------------------------------------------
# Dual-Stack Proxy-Only Subnet (Required for Regional/Cross-Region IPv6 Backends)
# Note: Proxy-only subnets cannot be created with stack_type = IPV6_ONLY.
#       Google Cloud automatically allocates the IPv6 range from the VPC's ULA
#       range when stack_type = IPV4_IPV6.
# ------------------------------------------------------------------------------
resource "google_compute_subnetwork" "proxy_only" {
  name             = "${var.name_prefix}-proxy-only"
  region           = var.region
  network          = google_compute_network.lab.id
  purpose          = "REGIONAL_MANAGED_PROXY"
  role             = "ACTIVE"
  ip_cidr_range    = var.proxy_only_subnet_cidr
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
}

# ------------------------------------------------------------------------------
# IPv6-Only Backend Subnet (Internal IPv6 ULA)
# ------------------------------------------------------------------------------
resource "google_compute_subnetwork" "backends" {
  name             = "${var.name_prefix}-backends-v6"
  region           = var.region
  network          = google_compute_network.lab.id
  stack_type       = "IPV6_ONLY"
  ipv6_access_type = "INTERNAL"
}

# ------------------------------------------------------------------------------
# Regional External IPv6 Frontend Subnet (External IPv6 for Forwarding Rule)
# ------------------------------------------------------------------------------
resource "google_compute_subnetwork" "frontend_v6" {
  name             = "${var.name_prefix}-frontend-v6"
  region           = var.region
  network          = google_compute_network.lab.id
  stack_type       = "IPV6_ONLY"
  ipv6_access_type = "EXTERNAL"
}

# ------------------------------------------------------------------------------
# Firewall Rules for IPv6-Only Backends
# 1) Allow HTTP/80 from the dual-stack proxy-only subnet's auto-allocated IPv6 range
# 2) Allow HTTP/80 from Google Cloud's documented IPv6 health-check probe ranges
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_proxy_ipv6" {
  name          = "${var.name_prefix}-allow-proxy-v6"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = [google_compute_subnetwork.proxy_only.ipv6_cidr_range]
  target_tags   = ["ipv6-lb-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_hc_ipv6" {
  name          = "${var.name_prefix}-allow-hc-v6"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = var.health_check_ipv6_source_ranges
  target_tags   = ["ipv6-lb-backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# ------------------------------------------------------------------------------
# IPv6-Only Backend VM Template and Managed Instance Group
# ------------------------------------------------------------------------------
resource "google_compute_instance_template" "backend_v6" {
  name_prefix  = "${var.name_prefix}-tpl-"
  machine_type = var.machine_type
  tags         = ["ipv6-lb-backend"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.backends.id
    stack_type = "IPV6_ONLY"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail
    cat <<'PYEOF' > /usr/local/bin/ipv6_backend.py
    import http.server, socket, socketserver

    class HTTPServerV6(http.server.HTTPServer):
        address_family = socket.AF_INET6

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            body = (
                f"backend={socket.gethostname()}\n"
                f"remote={self.client_address[0]}\n"
                f"xff={self.headers.get('X-Forwarded-For', '')}\n"
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    HTTPServerV6(("::", 80), Handler).serve_forever()
    PYEOF
    nohup python3 /usr/local/bin/ipv6_backend.py >/var/log/ipv6_backend.log 2>&1 &
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "backend_v6" {
  name               = "${var.name_prefix}-mig"
  zone               = var.zone
  base_instance_name = "${var.name_prefix}-vm"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.backend_v6.id
  }

  named_port {
    name = "http"
    port = 80
  }
}

# ------------------------------------------------------------------------------
# Regional HTTP Health Check (runs over IPv6 when backend service uses IPV6_ONLY)
# ------------------------------------------------------------------------------
resource "google_compute_region_health_check" "http" {
  name   = "${var.name_prefix}-hc"
  region = var.region

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# ------------------------------------------------------------------------------
# Regional External Application Load Balancer Backend Service (IPV6_ONLY)
# ------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "ipv6_only" {
  provider                    = google-beta
  name                        = "${var.name_prefix}-bs"
  region                      = var.region
  load_balancing_scheme       = "EXTERNAL_MANAGED"
  protocol                    = "HTTP"
  port_name                   = "http"
  ip_address_selection_policy = "IPV6_ONLY"
  health_checks               = [google_compute_region_health_check.http.id]

  backend {
    group           = google_compute_instance_group_manager.backend_v6.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "lab" {
  name            = "${var.name_prefix}-urlmap"
  region          = var.region
  default_service = google_compute_region_backend_service.ipv6_only.id
}

resource "google_compute_region_target_http_proxy" "lab" {
  name    = "${var.name_prefix}-http-proxy"
  region  = var.region
  url_map = google_compute_region_url_map.lab.id
}

# ------------------------------------------------------------------------------
# Dual Frontends: IPv4 Forwarding Rule + IPv6 Forwarding Rule
# Both terminate client connections at the Envoy proxy and forward IPv6 only
# to the IPv6-only backend instance group.
# ------------------------------------------------------------------------------
resource "google_compute_address" "frontend_ipv4" {
  name         = "${var.name_prefix}-fe-ipv4"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

resource "google_compute_forwarding_rule" "frontend_ipv4" {
  name                  = "${var.name_prefix}-fr-ipv4"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network               = google_compute_network.lab.id
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_address.frontend_ipv4.address
  network_tier          = "STANDARD"
  target                = google_compute_region_target_http_proxy.lab.id

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_address" "frontend_ipv6" {
  name               = "${var.name_prefix}-fe-ipv6"
  region             = var.region
  address_type       = "EXTERNAL"
  ip_version         = "IPV6"
  ipv6_endpoint_type = "NETLB"
  subnetwork         = google_compute_subnetwork.frontend_v6.id
  network_tier       = "STANDARD"
}

resource "google_compute_forwarding_rule" "frontend_ipv6" {
  name                  = "${var.name_prefix}-fr-ipv6"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network               = google_compute_network.lab.id
  subnetwork            = google_compute_subnetwork.frontend_v6.id
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_address.frontend_ipv6.address
  ip_version            = "IPV6"
  network_tier          = "STANDARD"
  target                = google_compute_region_target_http_proxy.lab.id

  depends_on = [google_compute_subnetwork.proxy_only]
}
