data "google_project" "host" {
  provider   = google.host
  project_id = var.host_project_id
}

data "google_project" "service" {
  provider   = google.service
  project_id = var.service_project_id
}

locals {
  host_apis = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "networkconnectivity.googleapis.com",
  ])
  service_apis = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "run.googleapis.com",
    "iam.googleapis.com",
    "networkservices.googleapis.com",
    "networksecurity.googleapis.com",
    "networkconnectivity.googleapis.com",
    "discoveryengine.googleapis.com",
    "agentregistry.googleapis.com",
  ])
  agw_sa             = "serviceAccount:service-${data.google_project.service.number}@gcp-sa-agentgateway.iam.gserviceaccount.com"
  discovery_sa       = "serviceAccount:service-${data.google_project.service.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
  service_apis_sa    = "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com"
  service_compute_sa = "serviceAccount:${data.google_project.service.number}-compute@developer.iam.gserviceaccount.com"
}

resource "google_project_service" "host" {
  for_each           = local.host_apis
  provider           = google.host
  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service" {
  for_each           = local.service_apis
  provider           = google.service
  project            = var.service_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  provider = google.host
  project  = var.host_project_id

  depends_on = [google_project_service.host]
}

resource "google_compute_network" "host" {
  provider                = google.host
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.host]
}

resource "google_compute_subnetwork" "attachment" {
  provider                 = google.host
  name                     = var.attachment_subnet_name
  ip_cidr_range            = var.attachment_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.host.id
  stack_type               = "IPV4_ONLY"
  private_ip_google_access = true
}

resource "google_compute_shared_vpc_service_project" "service" {
  provider        = google.host
  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = var.service_project_id
}

# The service project's default identities, and the Agent Gateway service agent,
# need Network User on the shared subnet to create and use the network attachment.
resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = toset([
    local.service_apis_sa,
    local.service_compute_sa,
    local.agw_sa,
  ])

  provider   = google.host
  project    = var.host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.attachment.name
  role       = "roles/compute.networkUser"
  member     = each.value

  depends_on = [
    google_compute_shared_vpc_service_project.service,
    google_project_service.service,
  ]
}

resource "google_project_iam_member" "agw_on_host" {
  for_each = toset([
    "roles/compute.networkViewer",
    "roles/dns.reader",
    "roles/dns.peer",
  ])

  provider = google.host
  project  = var.host_project_id
  role     = each.value
  member   = local.agw_sa

  depends_on = [google_project_service.service]
}

# Reserved, non-overlapping global /32 used as the PSC endpoint for Google APIs.
resource "google_compute_global_address" "psc_googleapis" {
  provider     = google.host
  name         = "${var.name_prefix}-psc-googleapis"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.host.id
  address      = var.psc_google_apis_ip

  depends_on = [google_project_service.host]
}

resource "google_compute_global_forwarding_rule" "psc_googleapis" {
  provider              = google.host
  name                  = "${var.name_prefix}-psc-googleapis"
  ip_address            = google_compute_global_address.psc_googleapis.id
  network               = google_compute_network.host.id
  target                = "all-apis"
  load_balancing_scheme = ""
}

# Private zone in the host project, authorized for the Shared VPC. The
# connectivity template peers this suffix; Agent Gateway DNS peering does not
# accept a zone that lives only in a service project.
resource "google_dns_managed_zone" "run_app" {
  provider    = google.host
  name        = "${var.name_prefix}-run-app"
  dns_name    = var.dns_zone_dns_name
  description = "Private zone mapping ${var.dns_zone_dns_name} to the PSC Google APIs endpoint."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.host.id
    }
  }

  depends_on = [google_project_service.host]
}

resource "google_dns_record_set" "run_app_wildcard" {
  provider     = google.host
  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.run_app.name
  name         = "*.${var.dns_zone_dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.psc_google_apis_ip]
}

# Recommended topology: network attachment in the service project, using the host subnet.
resource "google_compute_network_attachment" "agw" {
  provider              = google.service
  name                  = "${var.name_prefix}-na"
  region                = var.region
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.attachment.id]

  depends_on = [
    google_compute_shared_vpc_service_project.service,
    google_compute_subnetwork_iam_member.network_user,
  ]
}

# Allow the attachment subnet to reach the PSC endpoint on TCP 443.
resource "google_compute_firewall" "attachment_to_psc" {
  provider = google.host
  name     = "${var.name_prefix}-attachment-to-psc"
  network  = google_compute_network.host.name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges      = [var.attachment_subnet_cidr]
  destination_ranges = ["${var.psc_google_apis_ip}/32"]
}

# Stand-in Cloud Run service with internal-only ingress. Replace mcp_image
# with a StreamableHTTP MCP server before using this as a real connector.
resource "google_cloud_run_v2_service" "mcp" {
  provider = google.service
  name     = var.mcp_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    containers {
      image = var.mcp_image
    }
  }

  deletion_protection = false

  depends_on = [google_project_service.service]
}

# Dual-header IAM path: Gemini Enterprise sends a Google-signed ID token in
# X-Serverless-Authorization only when the connector uses the default .run.app URL.
resource "google_cloud_run_v2_service_iam_member" "discovery_invoker" {
  provider = google.service
  project  = var.service_project_id
  location = var.region
  name     = google_cloud_run_v2_service.mcp.name
  role     = "roles/run.invoker"
  member   = local.discovery_sa

  depends_on = [google_project_service.service]
}

resource "google_network_services_agent_connectivity_template" "agw" {
  count                          = var.create_agent_gateway ? 1 : 0
  provider                       = google.service
  project                        = var.service_project_id
  agent_connectivity_template_id = "${var.name_prefix}-tmpl"
  location                       = var.region
  description                    = "Private ranges only, through the service-project network attachment, peering ${var.dns_zone_dns_name} to the host VPC."
  access_path                    = "AGENT_TO_ANYWHERE"
  deployment_model               = "CENTRALIZED"

  egress_network_config {
    vpc_egress         = "PRIVATE_RANGES_ONLY"
    network_attachment = google_compute_network_attachment.agw.id

    dns_peering_config {
      domains        = [var.dns_zone_dns_name]
      target_network = google_compute_network.host.id
    }
  }

  depends_on = [
    google_project_iam_member.agw_on_host,
    google_compute_subnetwork_iam_member.network_user,
    google_dns_record_set.run_app_wildcard,
    google_project_service.service,
  ]
}

resource "google_network_services_agent_gateway" "agw" {
  count       = var.create_agent_gateway ? 1 : 0
  provider    = google.service
  project     = var.service_project_id
  name        = "${var.name_prefix}-gw"
  location    = var.region
  description = "Egress Agent Gateway for private Cloud Run MCP connectivity."

  google_managed {
    governed_access_path = "AGENT_TO_ANYWHERE"
  }

  agent_connectivity_template = "projects/${data.google_project.service.number}/locations/${var.region}/agentConnectivityTemplates/${var.name_prefix}-tmpl"

  depends_on = [google_network_services_agent_connectivity_template.agw]
}
