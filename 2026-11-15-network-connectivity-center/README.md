# Network Connectivity Center star-topology lab

Practice lab for the Network Connectivity Center lesson in the [GCP new features](https://www.youtube.com/playlist?list=PLMJ6gO8q8Y0k) playlist. Folder: `2026-11-15-network-connectivity-center`.

This lab builds a star-topology hub, attaches one center VPC spoke and two edge VPC spokes, enables Private Service Connect propagation on the hub, and creates a small Debian VM in each VPC so you can prove the routing.

## Goals

- Create a Network Connectivity Center hub with `preset_topology = "STAR"` and `export_psc = true`.
- Attach custom-mode VPC networks as spokes in the `center` and `edge` groups.
- Confirm that an edge VM can reach the center VM, and that the two edge VMs cannot reach each other through the hub, even though firewalls allow ICMP among all three CIDRs.
- Inspect the hub, spokes, and route tables with `gcloud`.

## Prerequisites

- A Google Cloud project with billing enabled.
- Permissions to enable APIs, create VPC networks, firewalls, and VMs, and to administer Network Connectivity Center hubs and spokes. Project Owner, or Compute Network Admin plus NCC Admin, is enough for a single-project lab.
- The [Google Cloud CLI](https://cloud.google.com/sdk) and [Terraform](https://www.terraform.io/downloads) 1.6 or later.
- IAP TCP forwarding to SSH to the sample VMs, which have no external IP addresses. Grant yourself `roles/iap.tunnelResourceAccessor` if needed, and include your user in the IAP firewall path (already opened from `35.235.240.0/20`).

This configuration does not create hybrid spokes (HA VPN, Interconnect, or router appliance). Those need on-premises or partner circuits you probably do not want in a short practice lab.

## Steps

1. Copy the example variables and set your project:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edit project_id, and optionally region and zone
   ```

2. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Terraform enables `compute.googleapis.com` and `networkconnectivity.googleapis.com` (it does not disable them on destroy), creates three custom-mode VPCs and subnets, a star hub, three VPC spokes, firewall rules, and three `e2-micro` VMs.

3. Wait a minute after apply for spoke status to become `ACTIVE` and for subnet routes to appear in the hub groups.

## Verify

Replace `ZONE` with the zone you applied, default `us-central1-a`.

```bash
# Hub topology and PSC propagation
gcloud network-connectivity hubs describe ncc-lab-hub

# Spokes and their groups
gcloud network-connectivity spokes list --region=global

# Routes in each star group (center should see all three subnets;
# each edge table should see center plus itself, not the other edge)
gcloud network-connectivity hubs route-tables list --hub=ncc-lab-hub
```

SSH to the edge A VM and ping the other two internal IPs from `terraform output`:

```bash
gcloud compute ssh ncc-lab-edge-a-vm --zone=ZONE --tunnel-through-iap
# From the VM:
#   ping -c 3 CENTER_INTERNAL_IP    # should succeed
#   ping -c 3 EDGE_B_INTERNAL_IP    # should fail (no star east-west route)
```

You can also SSH to the center VM and ping both edges; those pings should succeed.

## Cleanup

```bash
terraform destroy
```

This deletes the VMs, spokes, hub, firewalls, subnets, and VPCs. It leaves the Compute Engine and Network Connectivity APIs enabled.

## Notes

- Auto mode VPC networks cannot be spokes; this lab uses custom mode only.
- A VPC spoke can join only one hub at a time. If you attach this network to another hub later, wait at least ten minutes after destroy.
- Enabling `export_psc` does not create a Private Service Connect endpoint. It only turns propagation on so endpoints you add later can be reached from other VPC spokes, subject to export filters and a possible delay of up to 24 hours.
- Do not commit `terraform.tfvars` or state files. A `.gitignore` at the repo root already excludes them.
