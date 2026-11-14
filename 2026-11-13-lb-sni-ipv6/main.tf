terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Dual-stack subnet that supplies the /96 IPv6 range for the regional
# external proxy Network Load Balancer IPv6 forwarding rule.
resource "google_compute_subnetwork" "frontend" {
  name             = "${var.name_prefix}-frontend"
  ip_cidr_range    = var.subnet_cidr
  region           = var.region
  network          = google_compute_network.lab.id
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
}

# Proxy-only subnet used by Envoy-based regional proxy load balancers.
resource "google_compute_subnetwork" "proxy" {
  name          = "${var.name_prefix}-proxy-only"
  ip_cidr_range = var.proxy_only_cidr
  region        = var.region
  network       = google_compute_network.lab.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  stack_type    = "IPV4_IPV6"
}

resource "google_compute_region_health_check" "tcp" {
  name               = "${var.name_prefix}-tcp-hc"
  region             = var.region
  timeout_sec        = 5
  check_interval_sec = 5

  tcp_health_check {
    port = 443
  }
}

resource "google_compute_region_backend_service" "app" {
  name                  = "${var.name_prefix}-app-bes"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.tcp.id]
  timeout_sec           = 30
}

resource "google_compute_region_backend_service" "api" {
  name                  = "${var.name_prefix}-api-bes"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.tcp.id]
  timeout_sec           = 30
}

# Regional external proxy Network Load Balancer target. TLS routes, not a
# backend service, select the destination from the TLS ClientHello SNI.
resource "google_compute_region_target_tcp_proxy" "lab" {
  name                  = "${var.name_prefix}-tcp-proxy"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"

  depends_on = [google_compute_subnetwork.proxy]
}

resource "google_network_services_tls_route" "lab" {
  name        = "${var.name_prefix}-tls-route"
  location    = var.region
  description = "SNI-based routing for a regional external proxy Network Load Balancer"

  target_proxies = [
    google_compute_region_target_tcp_proxy.lab.self_link,
  ]

  rules {
    matches {
      sni_host = [var.app_sni_host]
    }
    action {
      destinations {
        service_name = google_compute_region_backend_service.app.self_link
      }
    }
  }

  rules {
    matches {
      sni_host = [var.api_sni_host]
    }
    action {
      destinations {
        service_name = google_compute_region_backend_service.api.self_link
      }
    }
  }
}

resource "google_compute_forwarding_rule" "ipv4" {
  name                  = "${var.name_prefix}-fr-ipv4"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_tcp_proxy.lab.id
  network               = google_compute_network.lab.id
  network_tier          = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy]
}

resource "google_compute_forwarding_rule" "ipv6" {
  name                  = "${var.name_prefix}-fr-ipv6"
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_version            = "IPV6"
  port_range            = "443"
  target                = google_compute_region_target_tcp_proxy.lab.id
  network               = google_compute_network.lab.id
  subnetwork            = google_compute_subnetwork.frontend.id
  network_tier          = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy]
}
