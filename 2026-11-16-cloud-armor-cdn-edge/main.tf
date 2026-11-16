locals {
  apis = ["compute.googleapis.com", "storage.googleapis.com"]

  # CEL expressions for the edge policy. Header keys are lowercase.
  asn_expression    = "origin.asn == ${var.denied_asn}"
  path_expression   = "request.path.startsWith('${var.denied_path_prefix}')"
  header_expression = "has(request.headers['${var.denied_header_name}']) && request.headers['${var.denied_header_name}'] == '${var.denied_header_value}'"
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Cloud Storage origin and a Cloud CDN backend bucket.
# The bucket is private; this lab is about attaching the edge policy, not
# publishing a public site. Add a frontend only if you want to send test
# requests through a global external Application Load Balancer.
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "lab" {
  name                        = "${var.name_prefix}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.apis]
}

resource "google_compute_backend_bucket" "cdn" {
  name        = "${var.name_prefix}-backend"
  description = "Cloud CDN backend bucket protected by a Cloud Armor edge security policy."
  bucket_name = google_storage_bucket.lab.name
  enable_cdn  = true

  # Official field for a CLOUD_ARMOR_EDGE policy. Only edge policies can
  # attach to backend buckets.
  edge_security_policy = google_compute_security_policy.edge.id

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Globally scoped edge security policy for Cloud CDN.
# ASN, Network Threat Intelligence, and HTTP filtering for Cloud CDN edge
# cache services are Preview as of 2026-11-16.
# ---------------------------------------------------------------------------
resource "google_compute_security_policy" "edge" {
  name        = "${var.name_prefix}-policy"
  description = "Preview Cloud Armor edge policy: placeholder ASN, optional NTI, and HTTP filters for a Cloud CDN backend bucket."
  type        = "CLOUD_ARMOR_EDGE"

  # Lower number = earlier evaluation. 64512 is a documentation placeholder.
  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Deny a placeholder ASN. Replace denied_asn with a number you have investigated."
    preview     = false

    match {
      expr {
        expression = local.asn_expression
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1300
    description = "Deny requests whose path starts with the lab prefix."
    preview     = false

    match {
      expr {
        expression = local.path_expression
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1400
    description = "Deny requests that send the lab diagnostic header."
    preview     = false

    match {
      expr {
        expression = local.header_expression
      }
    }
  }

  # Default rule required by the API. Allows everything that did not match.
  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Network Threat Intelligence feeds require Cloud Armor Enterprise.
# These are separate rule resources so a Standard-tier project can keep the
# flag off and still apply the rest of the lab.
resource "google_compute_security_policy_rule" "tor_exits" {
  count = var.enable_threat_intelligence ? 1 : 0

  security_policy = google_compute_security_policy.edge.name
  action          = "deny(403)"
  priority        = 1100
  description     = "Deny Tor exit nodes (iplist-tor-exit-nodes). Requires Cloud Armor Enterprise."
  preview         = false

  match {
    expr {
      expression = "evaluateThreatIntelligence('iplist-tor-exit-nodes')"
    }
  }
}

resource "google_compute_security_policy_rule" "known_malicious" {
  count = var.enable_threat_intelligence ? 1 : 0

  security_policy = google_compute_security_policy.edge.name
  action          = "deny(403)"
  priority        = 1200
  description     = "Deny known-malicious IPs (iplist-known-malicious-ips). Requires Cloud Armor Enterprise."
  preview         = false

  match {
    expr {
      expression = "evaluateThreatIntelligence('iplist-known-malicious-ips')"
    }
  }
}
