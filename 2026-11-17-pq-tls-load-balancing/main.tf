locals {
  apis = ["compute.googleapis.com", "storage.googleapis.com"]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Two global SSL policies that differ only in post-quantum key exchange.
# Profile and minimum TLS version can be anything the feature supports;
# the hybrid group is still used only when the client also offers TLS 1.3.
# ---------------------------------------------------------------------------
resource "google_compute_ssl_policy" "keep" {
  name                      = "${var.name_prefix}-keep"
  description               = "Phase 2 default: allow X25519MLKEM768 with clients that advertise it."
  profile                   = "MODERN"
  min_tls_version           = "TLS_1_2"
  post_quantum_key_exchange = "DEFAULT"

  depends_on = [google_project_service.apis]
}

resource "google_compute_ssl_policy" "deferred" {
  name                      = "${var.name_prefix}-deferred"
  description               = "Temporary opt-out: disallow X25519MLKEM768 until October 2027."
  profile                   = "MODERN"
  min_tls_version           = "TLS_1_2"
  post_quantum_key_exchange = "DEFERRED"

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Optional global external Application Load Balancer used to show attaching
# one of those policies to a target HTTPS proxy. The origin is a private
# Cloud Storage bucket; this lab is about frontend TLS, not a public site.
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "lab" {
  count                       = var.create_load_balancer ? 1 : 0
  name                        = "${var.name_prefix}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.apis]
}

resource "google_compute_backend_bucket" "lab" {
  count       = var.create_load_balancer ? 1 : 0
  name        = "${var.name_prefix}-backend"
  description = "Origin for the lab HTTPS load balancer. Not a public site."
  bucket_name = google_storage_bucket.lab[0].name

  depends_on = [google_project_service.apis]
}

resource "google_compute_url_map" "lab" {
  count           = var.create_load_balancer ? 1 : 0
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_bucket.lab[0].id
}

resource "tls_private_key" "lab" {
  count     = var.create_load_balancer ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "lab" {
  count           = var.create_load_balancer ? 1 : 0
  private_key_pem = tls_private_key.lab[0].private_key_pem

  subject {
    common_name  = "pq-tls-lab.example"
    organization = "Terraform practice lab"
  }

  validity_period_hours = 24 * 30
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "google_compute_ssl_certificate" "lab" {
  count       = var.create_load_balancer ? 1 : 0
  name        = "${var.name_prefix}-cert"
  description = "Self-signed lab certificate. Replace with a real certificate before any non-lab use."
  certificate = tls_self_signed_cert.lab[0].cert_pem
  private_key = tls_private_key.lab[0].private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "lab" {
  count            = var.create_load_balancer ? 1 : 0
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.lab[0].id
  ssl_certificates = [google_compute_ssl_certificate.lab[0].id]
  ssl_policy       = var.ssl_policy_mode == "deferred" ? google_compute_ssl_policy.deferred.id : google_compute_ssl_policy.keep.id
}

resource "google_compute_global_address" "lab" {
  count       = var.create_load_balancer ? 1 : 0
  name        = "${var.name_prefix}-ip"
  description = "Reserved global IPv4 address for the lab forwarding rule. Destroy it when you finish; unused reserved IPs incur a charge."
  ip_version  = "IPV4"
}

resource "google_compute_global_forwarding_rule" "lab" {
  count                 = var.create_load_balancer ? 1 : 0
  name                  = "${var.name_prefix}-https"
  ip_address            = google_compute_global_address.lab[0].id
  ip_protocol           = "TCP"
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
  target                = google_compute_target_https_proxy.lab[0].id
}
