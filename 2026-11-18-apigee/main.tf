locals {
  peering  = var.networking_mode == "peering"
  lb_ip    = try(google_compute_global_address.lb[0].address, "")
  hostname = var.hostname != "" ? var.hostname : (local.lb_ip != "" ? "${local.lb_ip}.nip.io" : "${var.name_prefix}.example.internal")
}

resource "google_project_service" "apis" {
  for_each = toset([
    "apigee.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ---------- Your VPC ----------
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr
}

# ---------- Peering mode only: reserve a range and peer with service networking ----------
resource "google_compute_global_address" "apigee_range" {
  count         = local.peering ? 1 : 0
  name          = "${var.name_prefix}-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.peering_range_address
  prefix_length = var.peering_range_prefix
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "apigee" {
  count                   = local.peering ? 1 : 0
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_range[0].name]
}

# ---------- Apigee organization, instance, environments ----------
resource "google_apigee_organization" "org" {
  project_id          = var.project_id
  analytics_region    = var.analytics_region
  billing_type        = var.billing_type
  runtime_type        = "CLOUD"
  disable_vpc_peering = local.peering ? false : true
  authorized_network  = local.peering ? google_compute_network.vpc.id : null

  depends_on = [google_project_service.apis, google_service_networking_connection.apigee]

  timeouts {
    create = "60m"
  }
}

resource "google_apigee_instance" "runtime" {
  name               = "${var.name_prefix}-${var.region}"
  location           = var.region
  org_id             = google_apigee_organization.org.id
  peering_cidr_range = local.peering && var.billing_type == "EVALUATION" ? "SLASH_22" : null

  # Projects allowed to connect a PSC NEG to the instance service attachment (northbound).
  consumer_accept_list = [var.project_id]

  timeouts {
    create = "60m"
  }
}

resource "google_apigee_environment" "env" {
  for_each     = toset(var.environments)
  name         = each.value
  display_name = each.value
  org_id       = google_apigee_organization.org.id
}

resource "google_apigee_instance_attachment" "env" {
  for_each    = google_apigee_environment.env
  instance_id = google_apigee_instance.runtime.id
  environment = each.value.name
}

resource "google_apigee_envgroup" "group" {
  name      = "${var.name_prefix}-group"
  org_id    = google_apigee_organization.org.id
  hostnames = [local.hostname]
}

resource "google_apigee_envgroup_attachment" "env" {
  for_each    = google_apigee_environment.env
  envgroup_id = google_apigee_envgroup.group.id
  environment = each.value.name
}

# ---------- Northbound: global external Application Load Balancer -> PSC NEG -> Apigee ----------
resource "google_compute_global_address" "lb" {
  count = var.create_northbound_lb ? 1 : 0
  name  = "${var.name_prefix}-lb-ip"
}

resource "google_compute_region_network_endpoint_group" "apigee_psc" {
  count                 = var.create_northbound_lb ? 1 : 0
  name                  = "${var.name_prefix}-psc-neg"
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.runtime.service_attachment
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.lab.id
}

resource "google_compute_backend_service" "apigee" {
  count                 = var.create_northbound_lb ? 1 : 0
  name                  = "${var.name_prefix}-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc[0].id
  }
}

resource "google_compute_url_map" "apigee" {
  count           = var.create_northbound_lb ? 1 : 0
  name            = "${var.name_prefix}-urlmap"
  default_service = google_compute_backend_service.apigee[0].id
}

resource "google_compute_managed_ssl_certificate" "apigee" {
  count = var.create_northbound_lb ? 1 : 0
  name  = "${var.name_prefix}-cert"

  managed {
    domains = [local.hostname]
  }
}

resource "google_compute_target_https_proxy" "apigee" {
  count            = var.create_northbound_lb ? 1 : 0
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.apigee[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee[0].id]
}

resource "google_compute_global_forwarding_rule" "apigee" {
  count                 = var.create_northbound_lb ? 1 : 0
  name                  = "${var.name_prefix}-fr"
  target                = google_compute_target_https_proxy.apigee[0].id
  ip_address            = google_compute_global_address.lb[0].id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ---------- Southbound (optional): Apigee endpoint attachment -> your PSC service attachment ----------
resource "google_apigee_endpoint_attachment" "backend" {
  count                  = var.backend_service_attachment != "" ? 1 : 0
  org_id                 = google_apigee_organization.org.id
  endpoint_attachment_id = "${var.name_prefix}-backend"
  location               = var.region
  service_attachment     = var.backend_service_attachment
}
