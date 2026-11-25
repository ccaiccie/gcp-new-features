# GCP Cloud Load Balancing: IPv6-Only Backends Practice Lab

Practice lab accompanying the Network Technician lesson on **IPv6-only backends for Cloud Load Balancing** (Preview, November 23, 2026).

Repository target path: `https://github.com/ccaiccie/gcp-new-features/tree/main/2026-11-25-ipv6-only-lb-backends`

## What This Lab Builds

This lab deploys a **Regional External Application Load Balancer** (`EXTERNAL_MANAGED`) that accepts both **IPv4** and **IPv6** client traffic on its frontends and forwards **IPv6-only** traffic to an **IPv6-only Compute Engine Managed Instance Group**:

- Custom-mode VPC network with ULA internal IPv6 enabled (`enable_ula_internal_ipv6 = true`).
- Dual-stack (`IPV4_IPV6`) `REGIONAL_MANAGED_PROXY` proxy-only subnet (primary IPv4 CIDR `10.129.0.0/23`, plus an automatically allocated IPv6 ULA range). Proxy-only subnets cannot be created with `IPV6_ONLY`.
- IPv6-only internal backend subnet (`IPV6_ONLY`, `ipv6_access_type = INTERNAL`) for the backend VMs.
- IPv6-only external frontend subnet (`IPV6_ONLY`, `ipv6_access_type = EXTERNAL`) for the regional external IPv6 forwarding rule.
- Managed instance group of 2 `e2-micro` Debian 12 VMs with `IPV6_ONLY` network interfaces running a lightweight IPv6 HTTP server on port 80.
- Regional HTTP health check (executes over IPv6 when the backend service policy is `IPV6_ONLY`).
- Regional backend service (`google-beta`) configured with `ip_address_selection_policy = "IPV6_ONLY"`.
- Two external forwarding rules (one IPv4 and one IPv6) sharing the same regional target HTTP proxy and URL map.
- Two VPC ingress firewall rules:
  1. Allow TCP/80 from the dual-stack proxy-only subnet's auto-allocated IPv6 ULA CIDR.
  2. Allow TCP/80 from Google Cloud's documented IPv6 health-check probe ranges (passed via `var.health_check_ipv6_source_ranges`).

## Prerequisites

1. A Google Cloud project with billing enabled and the Compute Engine API (`compute.googleapis.com`) enabled.
2. Terraform `>= 1.6.0` (validated with `hashicorp/google` and `hashicorp/google-beta` `8.12.0`).
3. Google Cloud CLI (`gcloud`) authenticated with permissions to manage VPC networks, subnets, firewalls, Compute Engine instances, and Cloud Load Balancing resources:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```
4. Look up Google Cloud's current documented **IPv6 health-check probe IP ranges** in the official Firewall Rules for Health Checks documentation before creating `terraform.tfvars`.

## Apply

1. Copy the example variables file and fill in your `project_id` and `health_check_ipv6_source_ranges`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Verify with `gcloud` and `curl`

Run the included verification script or run the commands individually:

```bash
chmod +x verify.sh
./verify.sh YOUR_PROJECT_ID us-central1 ipv6-lb-lab-bs
```

Manual verification steps:

```bash
# 1. Confirm ipAddressSelectionPolicy is IPV6_ONLY
gcloud compute backend-services describe ipv6-lb-lab-bs \
  --region=us-central1 \
  --format="yaml(name,loadBalancingScheme,protocol,ipAddressSelectionPolicy)"

# 2. Confirm both IPv6-only backends are HEALTHY via IPv6 health checks
gcloud compute backend-services get-health ipv6-lb-lab-bs \
  --region=us-central1

# 3. Confirm the proxy-only subnet is dual-stack (IPV4_IPV6) with an auto-allocated ipv6CidrRange
gcloud compute networks subnets describe ipv6-lb-lab-proxy-only \
  --region=us-central1 \
  --format="yaml(name,purpose,role,stackType,ipCidrRange,ipv6CidrRange)"

# 4. Test the IPv4 frontend -> IPv6-only backend path
curl -4 -i "http://$(terraform output -raw frontend_ipv4_address)/"

# 5. Test the IPv6 frontend -> IPv6-only backend path (from an IPv6-capable client)
# Strip the /96 suffix from frontend_ipv6_address and connect to an address in the /96 range
curl -6 -i "http://[<FRONTEND_IPV6_ADDRESS>]/"
```

### Optional `gcloud` Command to Create a Dual-Stack Proxy-Only Subnet Directly

If you are creating a regional or cross-region dual-stack proxy-only subnet with `gcloud` outside Terraform:

```bash
gcloud compute networks subnets create ipv6-lb-lab-proxy-only \
  --purpose=REGIONAL_MANAGED_PROXY \
  --role=ACTIVE \
  --region=us-central1 \
  --network=ipv6-lb-lab-vpc \
  --range=10.129.0.0/23 \
  --stack-type=IPV4_IPV6
```

Use `--purpose=GLOBAL_MANAGED_PROXY` instead if you are deploying a cross-region internal Application Load Balancer or cross-region internal proxy Network Load Balancer.

## Cleanup

Destroy all lab resources when finished to stop billing:

```bash
terraform destroy
```

## Cost Notes

Running this lab incurs standard Google Cloud charges while provisioned:
- Two `e2-micro` Compute Engine VMs (plus boot disks).
- Regional External Application Load Balancer forwarding rules (two forwarding rules: IPv4 and IPv6) and processed data volume.
- Reserved static external IPv4 address (if unused) and network egress.
- Google Cloud does **not** charge for reserving IP addresses in a proxy-only subnet, and regional external Application Load Balancers do not incur hourly proxy instance charges.

Destroy the lab promptly after testing to keep costs minimal (typically well under $1 for a short test session).

## Honest Provider & Preview Notes

- **Preview Status**: IPv6-only backends for global, regional, and cross-region Application Load Balancers and proxy Network Load Balancers entered Preview on November 23, 2026. Classic Application Load Balancers and Classic proxy Network Load Balancers are excluded.
- **No Policy Validation**: Cloud Load Balancing does not validate that attached backends match `ipAddressSelectionPolicy = IPV6_ONLY`. Attaching IPv4-only backends results in failed IPv6 health checks and HTTP `503` responses to clients.
- **Terraform Provider (`google-beta`)**: `google_compute_region_backend_service.ip_address_selection_policy` is configured via the `google-beta` provider (`>= 6.0.0`, validated on `8.12.0`). If your project or region requires `gcloud beta` during Preview, you can update the policy directly with `gcloud compute backend-services update` (or `gcloud beta compute backend-services update`) or in the Google Cloud Console under **Network Services > Load balancing > Backend services**.
- **Zonal NEG Alternative**: This lab uses an IPv6-only VM instance group. Zonal NEGs with `GCE_VM_IP_PORT` endpoints are also supported in Preview.

## Official Documentation

- https://docs.cloud.google.com/release-notes
- https://docs.cloud.google.com/load-balancing/docs/ipv6
- https://docs.cloud.google.com/load-balancing/docs/backend-service
- https://docs.cloud.google.com/load-balancing/docs/proxy-only-subnets
