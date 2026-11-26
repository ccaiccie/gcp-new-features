locals {
  ngfw_parent = var.use_project_scope ? "projects/${var.project_id}" : "organizations/${var.organization_id}"
  spg_policy_ref = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.urlf_group.id}"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "networksecurity.googleapis.com",
    "iap.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Custom VPC with 1460 MTU to match a standard Cloud NGFW firewall endpoint
resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.prefix}-subnet"
  ip_cidr_range            = "10.10.0.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Cloud Router and Cloud NAT provide egress internet access for the private VM
resource "google_compute_router" "router" {
  name    = "${var.prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Private test VM without an external IPv4 address (connect via IAP SSH)
resource "google_compute_instance" "test_vm" {
  name         = "${var.prefix}-client"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    # No access_config block: private IP only
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  depends_on = [google_compute_router_nat.nat]
}

# 1. URL Filtering Security Profile (implicit DENY '*' at priority 2147483647 is added automatically)
resource "google_network_security_security_profile" "urlf_profile" {
  name        = "${var.prefix}-urlf-profile"
  parent      = local.ngfw_parent
  location    = "global"
  type        = "URL_FILTERING"
  description = "Egress HTTP and HTTPS domain/SNI URL filtering profile"

  url_filtering_profile {
    url_filters {
      priority         = 500
      filtering_action = "DENY"
      urls             = var.denied_domains
    }

    url_filters {
      priority         = 1000
      filtering_action = "ALLOW"
      urls             = var.allowed_domains
    }
  }

  depends_on = [google_project_service.apis]
}

# 2. Security Profile Group wrapping the URL filtering profile
resource "google_network_security_security_profile_group" "urlf_group" {
  name                  = "${var.prefix}-urlf-spg"
  parent                = local.ngfw_parent
  location              = "global"
  description           = "Security profile group for Cloud NGFW URL filtering"
  url_filtering_profile = google_network_security_security_profile.urlf_profile.id
}

# 3. Zonal Cloud NGFW Firewall Endpoint in the same zone as the test VM
resource "google_network_security_firewall_endpoint" "endpoint" {
  name               = "${var.prefix}-endpoint"
  parent             = local.ngfw_parent
  location           = var.zone
  billing_project_id = var.project_id

  depends_on = [google_project_service.apis]
}

# 4. Associate the zonal Firewall Endpoint with the VPC
resource "google_network_security_firewall_endpoint_association" "endpoint_assoc" {
  name              = "${var.prefix}-endpoint-assoc"
  parent            = "projects/${var.project_id}"
  location          = var.zone
  network           = google_compute_network.vpc.id
  firewall_endpoint = google_network_security_firewall_endpoint.endpoint.id
}

# 5. Global Network Firewall Policy attached to the VPC
resource "google_compute_network_firewall_policy" "fw_policy" {
  name        = "${var.prefix}-fw-policy"
  description = "Global network firewall policy with Cloud NGFW URL filtering"
  depends_on  = [google_project_service.apis]
}

resource "google_compute_network_firewall_policy_association" "fw_policy_assoc" {
  name              = "${var.prefix}-fw-policy-assoc"
  attachment_target = google_compute_network.vpc.id
  firewall_policy   = google_compute_network_firewall_policy.fw_policy.name
}

# Ingress rule allowing IAP SSH into the private VM
resource "google_compute_network_firewall_policy_rule" "allow_iap_ssh" {
  firewall_policy = google_compute_network_firewall_policy.fw_policy.name
  priority        = 100
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = true
  description     = "Allow IAP TCP forwarding for SSH to private test VM"

  match {
    src_ip_ranges = ["35.235.240.0/20"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22"]
    }
  }
}

# Egress rule applying the URL filtering Security Profile Group on HTTP/HTTPS
resource "google_compute_network_firewall_policy_rule" "egress_url_filtering" {
  firewall_policy        = google_compute_network_firewall_policy.fw_policy.name
  priority               = 200
  direction              = "EGRESS"
  action                 = "apply_security_profile_group"
  security_profile_group = local.spg_policy_ref
  enable_logging         = true
  description            = "Inspect egress HTTP and HTTPS traffic with URL filtering"

  match {
    dest_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["80", "443"]
    }
  }

  depends_on = [google_network_security_firewall_endpoint_association.endpoint_assoc]
}
