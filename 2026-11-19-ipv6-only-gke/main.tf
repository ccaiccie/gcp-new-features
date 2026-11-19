locals {
  services = ["compute.googleapis.com", "container.googleapis.com", "dns.googleapis.com"]

  cluster_name = "${var.name_prefix}-cluster"

  # The hashicorp/google provider (8.12.0) only accepts IPV4 or IPV4_IPV6 for
  # google_container_cluster.ip_allocation_policy.stack_type, so the cluster
  # itself is created with the documented gcloud command.
  cluster_create_cmd = join(" ", [
    "gcloud container clusters create ${local.cluster_name}",
    "--project=${var.project_id}",
    "--location=${var.cluster_location}",
    "--cluster-version=${var.cluster_version}",
    "--enable-dataplane-v2",
    "--cluster-dns=clouddns",
    "--stack-type=ipv6",
    "--network=${google_compute_network.vpc.name}",
    "--subnetwork=${google_compute_subnetwork.nodes.name}",
    "--private-endpoint-subnetwork=${google_compute_subnetwork.psc.name}",
    "--machine-type=${var.machine_type}",
    "--num-nodes=${var.num_nodes}",
    "--quiet",
  ])
}

resource "google_project_service" "apis" {
  for_each           = toset(local.services)
  service            = each.value
  disable_on_destroy = false
}

# Custom-mode VPC with internal ULA IPv6 (a /48 from fd20::/20).
resource "google_compute_network" "vpc" {
  name                     = "${var.name_prefix}-vpc"
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true

  depends_on = [google_project_service.apis]
}

# IPv6-only node subnet: GKE carves a /96 per node and a /112 pod range per node from it.
resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.name_prefix}-nodes"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  stack_type               = "IPV6_ONLY"
  ipv6_access_type         = "INTERNAL"
  private_ip_google_access = true
}

# IPv6-only INTERNAL subnet for the Private Service Connect control plane endpoint
# (passed to gcloud as --private-endpoint-subnetwork).
resource "google_compute_subnetwork" "psc" {
  name             = "${var.name_prefix}-psc-cp"
  region           = var.region
  network          = google_compute_network.vpc.id
  stack_type       = "IPV6_ONLY"
  ipv6_access_type = "INTERNAL"
}

# DNS64: when a name has no AAAA record, Cloud DNS synthesizes one from the A record
# inside 64:ff9b::/96 (for example 198.51.100.20 -> 64:ff9b::c633:6414).
resource "google_dns_policy" "dns64" {
  name           = "${var.name_prefix}-dns64"
  description    = "DNS64 for the single-stack IPv6 GKE lab"
  enable_logging = true

  dns64_config {
    scope {
      all_queries = true
    }
  }

  networks {
    network_url = google_compute_network.vpc.id
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# One static external IPv4 address so you can prove what the internet sees.
resource "google_compute_address" "nat64" {
  name   = "${var.name_prefix}-nat64-ip"
  region = var.region
}

# Public Cloud NAT with NAT64 for the IPv6-only node subnet.
# source_subnetwork_ip_ranges_to_nat (NAT44) is a required argument in the provider.
# This VPC has no IPv4 subnets, so LIST_OF_SUBNETWORKS with no subnetwork blocks
# translates nothing for IPv4. See var.nat44_option and the README if the API rejects it.
resource "google_compute_router_nat" "nat64" {
  name                   = "${var.name_prefix}-nat64"
  router                 = google_compute_router.router.name
  region                 = var.region
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.nat64.self_link]

  source_subnetwork_ip_ranges_to_nat = var.nat44_option

  source_subnetwork_ip_ranges_to_nat64 = "LIST_OF_IPV6_SUBNETWORKS"
  nat64_subnetwork {
    name = google_compute_subnetwork.nodes.self_link
  }

  log_config {
    enable = true
    filter = var.nat_log_filter
  }
}

# East-west IPv6 inside the VPC's ULA /48 (GKE also creates its own cluster rules).
resource "google_compute_firewall" "allow_internal_v6" {
  name          = "${var.name_prefix}-allow-internal-v6"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [google_compute_network.vpc.internal_ipv6_range]

  allow {
    protocol = "all"
  }
}

# Single-stack IPv6 cluster through gcloud (Preview). Created after DNS64 and NAT64 so
# nodes can pull IPv4-only images, and deleted before the subnets on destroy.
resource "terraform_data" "cluster" {
  count = var.create_cluster ? 1 : 0

  input = {
    name     = local.cluster_name
    location = var.cluster_location
    project  = var.project_id
  }

  triggers_replace = [local.cluster_create_cmd]

  provisioner "local-exec" {
    command = local.cluster_create_cmd
  }

  provisioner "local-exec" {
    when    = destroy
    command = "gcloud container clusters delete ${self.input.name} --project=${self.input.project} --location=${self.input.location} --quiet"
  }

  depends_on = [
    google_compute_router_nat.nat64,
    google_dns_policy.dns64,
    google_compute_firewall.allow_internal_v6,
  ]
}
