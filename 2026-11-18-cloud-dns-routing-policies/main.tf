# Cloud DNS routing policies in a public zone: weighted round robin (canary),
# geolocation with health-checked external endpoints, and failover with trickle traffic.

resource "google_project_service" "dns" {
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_dns_managed_zone" "lab" {
  name        = "${var.name_prefix}-zone"
  dns_name    = var.dns_domain
  description = "Cloud DNS routing policy lab (public zone)"
  visibility  = "public"

  depends_on = [google_project_service.dns]
}

# Global health check for external endpoints: three source regions x three probers = nine probers.
# Interval must be 30 to 300 seconds. TCP, HTTP and HTTPS are supported.
resource "google_compute_health_check" "endpoints" {
  name                = "${var.name_prefix}-endpoints-tcp"
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  source_regions      = var.health_check_source_regions

  tcp_health_check {
    port = var.health_check_port
  }

  depends_on = [google_project_service.compute]
}

# 1) Weighted round robin: a canary split such as 900 / 100 (no health checks).
resource "google_dns_record_set" "canary" {
  managed_zone = google_dns_managed_zone.lab.name
  name         = "canary.${google_dns_managed_zone.lab.dns_name}"
  type         = "A"
  ttl          = var.ttl

  routing_policy {
    wrr {
      weight  = var.canary_current_weight
      rrdatas = [var.canary_current_ip]
    }
    wrr {
      weight  = var.canary_new_weight
      rrdatas = [var.canary_new_ip]
    }
  }
}

# 2) Geolocation with health-checked external endpoints. Without a geofence,
#    an unhealthy region fails over to the next closest healthy region.
resource "google_dns_record_set" "geo" {
  managed_zone = google_dns_managed_zone.lab.name
  name         = "app.${google_dns_managed_zone.lab.dns_name}"
  type         = "A"
  ttl          = var.ttl

  routing_policy {
    health_check       = google_compute_health_check.endpoints.id
    enable_geo_fencing = var.enable_geo_fencing

    geo {
      location = "europe-west3"
      health_checked_targets {
        external_endpoints = [var.europe_endpoint_ip]
      }
    }
    geo {
      location = "us-east4"
      health_checked_targets {
        external_endpoints = [var.us_endpoint_ip]
      }
    }
  }
}

# 3) Failover (primary and backup). The backup is a geolocation set;
#    trickle_ratio keeps the backup warm, 1.0 forces a manual failover.
resource "google_dns_record_set" "failover" {
  managed_zone = google_dns_managed_zone.lab.name
  name         = "ha.${google_dns_managed_zone.lab.dns_name}"
  type         = "A"
  ttl          = var.ttl

  routing_policy {
    health_check = google_compute_health_check.endpoints.id

    primary_backup {
      trickle_ratio = var.trickle_ratio

      primary {
        external_endpoints = [var.us_endpoint_ip]
      }

      backup_geo {
        location = "europe-west3"
        health_checked_targets {
          external_endpoints = [var.europe_endpoint_ip]
        }
      }
    }
  }
}
