# ==============================================================================
# Google Cloud Certificate Manager + Certificate Map on Application Load Balancer
# Practice Lab (Terraform)
#
# COST WARNING:
# Application Load Balancer resources, forwarding rules, and reserved external
# IP addresses incur charges until they are deleted. Run `terraform destroy`
# immediately after finishing this lab.
# ==============================================================================

# 1. DNS Authorization (covers both var.domain_name and *.var.domain_name)
resource "google_certificate_manager_dns_authorization" "default" {
  name        = "${var.name_prefix}-dns-auth"
  description = "DNS authorization for ${var.domain_name} and wildcard"
  domain      = var.domain_name
  type        = var.dns_authorization_type

  labels = {
    lab = "certificate-manager-maps"
  }
}

# 2. Optional Cloud DNS CNAME validation record
# If you manage DNS outside Cloud DNS, leave create_cloud_dns_record = false
# and publish the CNAME shown in `terraform output dns_authorization_cname`.
resource "google_dns_record_set" "dns_auth_cname" {
  count = var.create_cloud_dns_record ? 1 : 0

  name         = google_certificate_manager_dns_authorization.default.dns_resource_record[0].name
  managed_zone = var.cloud_dns_managed_zone
  type         = google_certificate_manager_dns_authorization.default.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.default.dns_resource_record[0].data]
}

# 3. Google-managed certificate referencing the DNS authorization
resource "google_certificate_manager_certificate" "default" {
  name        = "${var.name_prefix}-managed-cert"
  description = "Google-managed certificate for ${var.domain_name} and wildcard"
  scope       = "DEFAULT"

  managed {
    domains = [
      var.domain_name,
      "*.${var.domain_name}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default.id,
    ]
  }

  labels = {
    lab = "certificate-manager-maps"
  }
}

# 4. Certificate Map
resource "google_certificate_manager_certificate_map" "default" {
  name        = "${var.name_prefix}-cert-map"
  description = "Certificate map for ${var.domain_name}"

  labels = {
    lab = "certificate-manager-maps"
  }
}

# 5a. Certificate Map Entry — exact root/target hostname
resource "google_certificate_manager_certificate_map_entry" "exact_hostname" {
  name         = "${var.name_prefix}-entry-exact"
  description  = "Exact hostname match for ${var.domain_name}"
  map          = google_certificate_manager_certificate_map.default.name
  hostname     = var.domain_name
  certificates = [google_certificate_manager_certificate.default.id]

  labels = {
    lab = "certificate-manager-maps"
  }
}

# 5b. Certificate Map Entry — wildcard first-level subdomains
resource "google_certificate_manager_certificate_map_entry" "wildcard_hostname" {
  name         = "${var.name_prefix}-entry-wildcard"
  description  = "Wildcard hostname match for *.${var.domain_name}"
  map          = google_certificate_manager_certificate_map.default.name
  hostname     = "*.${var.domain_name}"
  certificates = [google_certificate_manager_certificate.default.id]

  labels = {
    lab = "certificate-manager-maps"
  }
}

# 5c. Certificate Map Entry — PRIMARY fallback (used when no exact/wildcard match)
# Note: Primary certificate map entries are incompatible with Identity-Aware Proxy (IAP).
resource "google_certificate_manager_certificate_map_entry" "primary" {
  name         = "${var.name_prefix}-entry-primary"
  description  = "Primary fallback certificate map entry"
  map          = google_certificate_manager_certificate_map.default.name
  matcher      = "PRIMARY"
  certificates = [google_certificate_manager_certificate.default.id]

  labels = {
    lab = "certificate-manager-maps"
  }
}

# ==============================================================================
# Minimal Global External Application Load Balancer Frontend
# ==============================================================================

resource "google_compute_global_address" "lb_ip" {
  name = "${var.name_prefix}-lb-ip"
}

resource "google_compute_health_check" "default" {
  name = "${var.name_prefix}-hc"

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "${var.name_prefix}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.default.id]
}

resource "google_compute_url_map" "default" {
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_service.default.id
}

# 6. Attach the Certificate Map to the Target HTTPS Proxy
resource "google_compute_target_https_proxy" "default" {
  name            = "${var.name_prefix}-https-proxy"
  url_map         = google_compute_url_map.default.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"

  depends_on = [
    google_certificate_manager_certificate_map_entry.exact_hostname,
    google_certificate_manager_certificate_map_entry.wildcard_hostname,
    google_certificate_manager_certificate_map_entry.primary,
  ]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https-fr"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = google_compute_global_address.lb_ip.id
}
