terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

# Certificate used by Secure Web Proxy. Generated at apply time; the private
# key is not written to this repository.
resource "tls_private_key" "swp" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "swp" {
  private_key_pem       = tls_private_key.swp.private_key_pem
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  dns_names             = [var.certificate_dns_name]

  subject {
    common_name  = var.certificate_dns_name
    organization = "SWP agent gateway lab"
  }
}

resource "google_certificate_manager_certificate" "swp" {
  name     = "${var.name_prefix}-cert"
  location = var.region

  self_managed {
    pem_certificate = tls_self_signed_cert.swp.cert_pem
    pem_private_key = tls_private_key.swp.private_key_pem
  }
}

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.name_prefix}-subnet"
  purpose       = "PRIVATE"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.lab.id
  role          = "ACTIVE"
}

resource "google_compute_subnetwork" "proxy" {
  name          = "${var.name_prefix}-proxy-only"
  purpose       = "REGIONAL_MANAGED_PROXY"
  ip_cidr_range = var.proxy_only_cidr
  region        = var.region
  network       = google_compute_network.lab.id
  role          = "ACTIVE"
}

resource "google_network_security_gateway_security_policy" "lab" {
  name        = "${var.name_prefix}-swp-policy"
  location    = var.region
  description = "Secure Web Proxy policy used by the agent gateway lab"
}

resource "google_network_security_gateway_security_policy_rule" "allow_example" {
  name                    = "${var.name_prefix}-allow-example"
  location                = var.region
  gateway_security_policy = google_network_security_gateway_security_policy.lab.name
  enabled                 = true
  priority                = 1000
  session_matcher         = "host() == '${var.allow_host}'"
  basic_profile           = "ALLOW"
}

resource "google_network_services_gateway" "swp" {
  name                                 = "${var.name_prefix}-swp"
  location                             = var.region
  type                                 = "SECURE_WEB_GATEWAY"
  ports                                = [443]
  scope                                = var.name_prefix
  certificate_urls                     = [google_certificate_manager_certificate.swp.id]
  gateway_security_policy              = google_network_security_gateway_security_policy.lab.id
  network                              = google_compute_network.lab.id
  subnetwork                           = google_compute_subnetwork.lab.id
  delete_swg_autogen_router_on_destroy = true

  depends_on = [google_compute_subnetwork.proxy]
}

# Preview: attaching an Agent Gateway to the Secure Web Proxy. Access is
# documented as request-based (Agent Governance Preview).
resource "google_network_services_agent_gateway" "lab" {
  name        = "${var.name_prefix}-agent-gw"
  location    = var.region
  description = "Agent Gateway in self-managed mode, attached to Secure Web Proxy"

  self_managed {
    resource_uri = google_network_services_gateway.swp.id
  }

  registries = var.include_registry ? [
    "//agentregistry.googleapis.com/projects/${data.google_project.current.project_id}/locations/${var.region}"
  ] : null
}
