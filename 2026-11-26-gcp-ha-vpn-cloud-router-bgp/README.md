# Google Cloud HA VPN & Cloud Router BGP — Practice Lab

Companion Terraform + `gcloud` lab for the **Network Technician** class on **Google Cloud HA VPN and Cloud Router BGP**.

## What This Lab Deploys
- **Two custom-mode VPC networks** in the same project and region (`vpc-a` with `10.10.1.0/24`, `vpc-b` with `10.20.1.0/24`) — an officially supported 99.99% SLA HA VPN VPC-to-VPC topology.
- **Two HA VPN gateways** (`gw-a` and `gw-b`), each automatically assigned two external IPv4 addresses (interface `0` and interface `1`) with no forwarding rules required.
- **Two Cloud Routers** (`router-a` ASN `65001`, `router-b` ASN `65002`) using **Custom advertisement mode** (`ALL_SUBNETS` + custom prefixes `10.10.250.0/24` and `10.20.250.0/24`).
- **Two redundant tunnel pairs** (`interface 0 <-> interface 0` and `interface 1 <-> interface 1`, IKEv2) with matching BGP sessions on `169.254.10.0/30` and `169.254.20.0/30`.
- **Configurable base route priorities (BGP MED)** (`tunnel0_base_priority` and `tunnel1_base_priority`, default `100`) to test both active-active and active-passive behavior.

## Prerequisites
- Google Cloud project with Compute Engine API enabled (`compute.googleapis.com`).
- `gcloud` CLI authenticated (`gcloud auth application-default login` and `gcloud config set project YOUR_PROJECT_ID`).
- Terraform `>= 1.5.0`.

## 1. Deploy the Lab
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id and a strong random shared_secret.
# NEVER commit terraform.tfvars!

terraform init
terraform plan
terraform apply
```

## 2. Verify Both Tunnels & BGP Sessions Are UP (Active-Active)
```bash
gcloud compute vpn-tunnels list --regions=us-central1

gcloud compute vpn-tunnels describe nt-havpn-a-to-b-0 --region=us-central1 \
  --format="value(name,status,detailedStatus)"

gcloud compute routers get-status nt-havpn-router-a --region=us-central1 \
  --format="table(result.bgpPeerStatus[].name,result.bgpPeerStatus[].status,result.bgpPeerStatus[].state,result.bgpPeerStatus[].numLearnedRoutes)"

gcloud compute routes list --filter="network:nt-havpn-vpc-a AND nextHopVpnTunnel:*"
```
You should see both tunnels in `ESTABLISHED` state, both BGP peers `UP` / `Established`, and dynamic routes in `vpc-a` for both `10.20.1.0/24` (subnet) and `10.20.250.0/24` (custom advertisement) with equal priority `100`.

## 3. Test Active-Passive Preference via Base Route Priority (BGP MED)
Keep both tunnels UP, but raise Tunnel 1's base priority to `150` (within Google's recommended `0-200` regional range):
```bash
terraform apply -var="tunnel1_base_priority=150"
```
Or update directly with `gcloud`:
```bash
gcloud compute routers update-bgp-peer nt-havpn-router-a \
  --region=us-central1 \
  --peer-name=bgp-a-to-b-1 \
  --advertised-route-priority=150
```
Re-run `gcloud compute routers get-status` and `gcloud compute routes list` to confirm Tunnel 0 (MED `100`) is now preferred over Tunnel 1 (MED `150`).

## 4. Simulate Single-Tunnel Failover
Temporarily remove Tunnel 1 on side A (or disable its BGP peer) to observe automatic BGP failover:
```bash
gcloud compute routers update-bgp-peer nt-havpn-router-a \
  --region=us-central1 \
  --peer-name=bgp-a-to-b-1 \
  --no-enable
```
Verify that `bgp-a-to-b-1` drops while `bgp-a-to-b-0` stays `Established` and dynamic routes to `10.20.1.0/24` and `10.20.250.0/24` remain installed over Tunnel 0:
```bash
gcloud compute routers get-status nt-havpn-router-a --region=us-central1
gcloud compute routes list --filter="network:nt-havpn-vpc-a AND nextHopVpnTunnel:*"
```
Re-enable the peer when finished:
```bash
gcloud compute routers update-bgp-peer nt-havpn-router-a \
  --region=us-central1 \
  --peer-name=bgp-a-to-b-1 \
  --enable
```

## 5. Tear Down Everything (Stop Hourly Charges)
HA VPN tunnels incur hourly charges while provisioned. Always destroy the lab when finished:
```bash
terraform destroy
```
Verify no gateways, tunnels, or routers remain:
```bash
gcloud compute vpn-gateways list --regions=us-central1
gcloud compute vpn-tunnels list --regions=us-central1
gcloud compute routers list --regions=us-central1
```
Deleting the HA VPN gateways automatically releases their Google-assigned external IP addresses.

## Official Google Cloud Documentation
- [Cloud VPN overview](https://cloud.google.com/network-connectivity/docs/vpn/concepts/overview)
- [HA VPN topologies](https://cloud.google.com/network-connectivity/docs/vpn/concepts/topologies)
- [Cloud Router overview](https://cloud.google.com/network-connectivity/docs/router/concepts/overview)
- [Create an HA VPN gateway to a peer VPN gateway](https://cloud.google.com/network-connectivity/docs/vpn/how-to/creating-ha-vpn)
- [Create HA VPN gateways to connect VPC networks](https://cloud.google.com/network-connectivity/docs/vpn/how-to/creating-ha-vpn2)
- [Cloud Router advertised routes](https://cloud.google.com/network-connectivity/docs/router/concepts/advertised-routes)
- [Update the base route priority](https://cloud.google.com/network-connectivity/docs/router/how-to/updating-priority)
