provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------
# 1. Two Custom-Mode VPC Networks & Subnets
# ------------------------------------------------------------------
resource "google_compute_network" "vpc_a" {
  name                    = "${var.name_prefix}-vpc-a"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet_a" {
  name          = "${var.name_prefix}-subnet-a"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_a.id
}

resource "google_compute_network" "vpc_b" {
  name                    = "${var.name_prefix}-vpc-b"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet_b" {
  name          = "${var.name_prefix}-subnet-b"
  ip_cidr_range = "10.20.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_b.id
}

# ------------------------------------------------------------------
# 2. Two HA VPN Gateways (2 auto-assigned external IPs each; no forwarding rules)
# ------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "gw_a" {
  name       = "${var.name_prefix}-gw-a"
  region     = var.region
  network    = google_compute_network.vpc_a.id
  stack_type = "IPV4_ONLY"
}

resource "google_compute_ha_vpn_gateway" "gw_b" {
  name       = "${var.name_prefix}-gw-b"
  region     = var.region
  network    = google_compute_network.vpc_b.id
  stack_type = "IPV4_ONLY"
}

# ------------------------------------------------------------------
# 3. Two Cloud Routers with Custom Advertisement Mode (+ ALL_SUBNETS)
# ------------------------------------------------------------------
resource "google_compute_router" "router_a" {
  name    = "${var.name_prefix}-router-a"
  region  = var.region
  network = google_compute_network.vpc_a.id

  bgp {
    asn               = var.router_a_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range       = var.custom_prefix_a
      description = "Lab custom prefix advertised from VPC A"
    }
  }
}

resource "google_compute_router" "router_b" {
  name    = "${var.name_prefix}-router-b"
  region  = var.region
  network = google_compute_network.vpc_b.id

  bgp {
    asn               = var.router_b_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range       = var.custom_prefix_b
      description = "Lab custom prefix advertised from VPC B"
    }
  }
}

# ------------------------------------------------------------------
# 4. Pair of HA VPN Tunnels (Interface 0 <-> Interface 0, Interface 1 <-> Interface 1)
#    Meets Google Cloud's 99.99% SLA topology requirement.
# ------------------------------------------------------------------
resource "google_compute_vpn_tunnel" "a_to_b_0" {
  name                  = "${var.name_prefix}-a-to-b-0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gw_a.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gw_b.id
  vpn_gateway_interface = 0
  shared_secret         = var.shared_secret
  router                = google_compute_router.router_a.id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "a_to_b_1" {
  name                  = "${var.name_prefix}-a-to-b-1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gw_a.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gw_b.id
  vpn_gateway_interface = 1
  shared_secret         = var.shared_secret
  router                = google_compute_router.router_a.id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "b_to_a_0" {
  name                  = "${var.name_prefix}-b-to-a-0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gw_b.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gw_a.id
  vpn_gateway_interface = 0
  shared_secret         = var.shared_secret
  router                = google_compute_router.router_b.id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "b_to_a_1" {
  name                  = "${var.name_prefix}-b-to-a-1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gw_b.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gw_a.id
  vpn_gateway_interface = 1
  shared_secret         = var.shared_secret
  router                = google_compute_router.router_b.id
  ike_version           = 2
}

# ------------------------------------------------------------------
# 5. BGP Router Interfaces & Peers (169.254.x.x/30 link-local)
# ------------------------------------------------------------------
resource "google_compute_router_interface" "if_a_0" {
  name       = "if-a-to-b-0"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.10.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.a_to_b_0.name
}

resource "google_compute_router_peer" "peer_a_0" {
  name                      = "bgp-a-to-b-0"
  router                    = google_compute_router.router_a.name
  region                    = var.region
  peer_ip_address           = "169.254.10.2"
  peer_asn                  = var.router_b_asn
  advertised_route_priority = var.tunnel0_base_priority
  interface                 = google_compute_router_interface.if_a_0.name
}

resource "google_compute_router_interface" "if_a_1" {
  name       = "if-a-to-b-1"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.20.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.a_to_b_1.name
}

resource "google_compute_router_peer" "peer_a_1" {
  name                      = "bgp-a-to-b-1"
  router                    = google_compute_router.router_a.name
  region                    = var.region
  peer_ip_address           = "169.254.20.2"
  peer_asn                  = var.router_b_asn
  advertised_route_priority = var.tunnel1_base_priority
  interface                 = google_compute_router_interface.if_a_1.name
}

resource "google_compute_router_interface" "if_b_0" {
  name       = "if-b-to-a-0"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.10.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.b_to_a_0.name
}

resource "google_compute_router_peer" "peer_b_0" {
  name                      = "bgp-b-to-a-0"
  router                    = google_compute_router.router_b.name
  region                    = var.region
  peer_ip_address           = "169.254.10.1"
  peer_asn                  = var.router_a_asn
  advertised_route_priority = var.tunnel0_base_priority
  interface                 = google_compute_router_interface.if_b_0.name
}

resource "google_compute_router_interface" "if_b_1" {
  name       = "if-b-to-a-1"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.20.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.b_to_a_1.name
}

resource "google_compute_router_peer" "peer_b_1" {
  name                      = "bgp-b-to-a-1"
  router                    = google_compute_router.router_b.name
  region                    = var.region
  peer_ip_address           = "169.254.20.1"
  peer_asn                  = var.router_a_asn
  advertised_route_priority = var.tunnel1_base_priority
  interface                 = google_compute_router_interface.if_b_1.name
}
