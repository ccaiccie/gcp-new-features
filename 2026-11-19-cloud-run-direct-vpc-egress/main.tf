# Cloud Run networking: Direct VPC egress versus Serverless VPC Access connectors
# Network Technician - GCP New Features - 2026-11-19

locals {
  apis = ["compute.googleapis.com", "run.googleapis.com", "vpcaccess.googleapis.com"]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------- network
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

# One subnet for Cloud Run (Direct VPC egress) and the backend VM.
# Private Google Access lets ALL_TRAFFIC egress still reach Google APIs.
resource "google_compute_subnetwork" "run" {
  name                     = "${var.name_prefix}-run-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.run_subnet_cidr
  private_ip_google_access = true
}

# ---------------------------------------------------------------- Cloud NAT with one static address
resource "google_compute_address" "nat" {
  name   = "${var.name_prefix}-nat-ip"
  region = var.region
}

resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.run.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------- backend VM (no external IP)
resource "google_compute_instance" "backend" {
  name         = "${var.name_prefix}-backend"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["backend"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.run.id
    network_ip = var.backend_ip
  }

  # Debian ships python3, so no package download is needed.
  metadata_startup_script = <<-EOT
    mkdir -p /srv/www
    echo "hello from the private backend $(hostname) at ${var.backend_ip}" > /srv/www/index.html
    cd /srv/www && nohup python3 -m http.server 80 >/var/log/backend-http.log 2>&1 &
  EOT

  shielded_instance_config {
    enable_secure_boot = true
  }
}

# ---------------------------------------------------------------- firewall
# Ingress to the backend: Cloud Run IPs are ephemeral and tags cannot be an ingress source,
# so allow the whole Cloud Run subnet range.
resource "google_compute_firewall" "backend_from_run_subnet" {
  name          = "${var.name_prefix}-allow-80-from-run-subnet"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.run_subnet_cidr]
  target_tags   = ["backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

# Optional: allow IAP TCP forwarding so you can SSH to the backend for troubleshooting.
resource "google_compute_firewall" "backend_iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["backend"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Egress for the Cloud Run revision/execution, selected by its network tag:
# deny everything at low priority, then allow only what the workload needs.
resource "google_compute_firewall" "run_deny_all_egress" {
  name               = "${var.name_prefix}-run-deny-all-egress"
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  priority           = 65000
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [var.network_tag]

  deny {
    protocol = "all"
  }
}

resource "google_compute_firewall" "run_allow_backend" {
  name               = "${var.name_prefix}-run-allow-backend-80"
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  priority           = 1000
  destination_ranges = ["${var.backend_ip}/32"]
  target_tags        = [var.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "run_allow_https_internet" {
  name               = "${var.name_prefix}-run-allow-443-out"
  network            = google_compute_network.vpc.id
  direction          = "EGRESS"
  priority           = 1100
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [var.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# ---------------------------------------------------------------- Cloud Run job with Direct VPC egress
resource "google_cloud_run_v2_job" "probe" {
  name                = "${var.name_prefix}-probe"
  location            = var.region
  deletion_protection = false

  template {
    task_count = 1

    template {
      max_retries = 0
      timeout     = "120s"

      containers {
        image   = "curlimages/curl:8.10.1"
        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          echo "== private backend via Direct VPC egress =="
          curl -sS -m 10 http://${var.backend_ip}/ || echo "backend: FAILED"
          echo "== public source address seen by the internet =="
          curl -sS -m 10 ${var.echo_url} || echo "echo: FAILED"
          echo
        EOT
        ]
      }

      vpc_access {
        egress = var.vpc_egress

        network_interfaces {
          network    = google_compute_network.vpc.id
          subnetwork = google_compute_subnetwork.run.id
          tags       = [var.network_tag]
        }
      }
    }
  }

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_instance.backend,
    google_compute_firewall.run_allow_backend,
    google_compute_firewall.run_allow_https_internet,
  ]
}

# ---------------------------------------------------------------- optional: the connector path
resource "google_vpc_access_connector" "connector" {
  count         = var.create_connector ? 1 : 0
  name          = "${var.name_prefix}-conn"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.connector_cidr
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
  depends_on    = [google_project_service.apis]
}

# Connector instances carry the tag "vpc-connector"; allow them to reach the backend.
resource "google_compute_firewall" "backend_from_connector" {
  count         = var.create_connector ? 1 : 0
  name          = "${var.name_prefix}-allow-80-from-connector"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.connector_cidr]
  target_tags   = ["backend"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_cloud_run_v2_job" "probe_connector" {
  count               = var.create_connector ? 1 : 0
  name                = "${var.name_prefix}-probe-connector"
  location            = var.region
  deletion_protection = false

  template {
    task_count = 1

    template {
      max_retries = 0
      timeout     = "120s"

      containers {
        image   = "curlimages/curl:8.10.1"
        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          echo "== private backend via Serverless VPC Access connector =="
          curl -sS -m 10 http://${var.backend_ip}/ || echo "backend: FAILED"
          echo "== public source address seen by the internet =="
          curl -sS -m 10 ${var.echo_url} || echo "echo: FAILED"
          echo
        EOT
        ]
      }

      vpc_access {
        connector = google_vpc_access_connector.connector[0].id
        egress    = var.vpc_egress
      }
    }
  }

  depends_on = [google_compute_firewall.backend_from_connector]
}
