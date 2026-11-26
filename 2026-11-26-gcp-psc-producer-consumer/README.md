# Google Cloud Private Service Connect: Producer Published Service to Consumer Endpoint Lab

This hands-on lab accompanies the **Network Technician** class on **Google Cloud Private Service Connect (PSC) Published Services**. It deploys a two-project architecture (a **Producer** project and a **Consumer** project) using Terraform and equivalent `gcloud` CLI commands—deliberately using the **same `10.10.1.0/24` CIDR** in both VPCs to prove that PSC requires zero IP coordination, zero VPC Network Peering, and zero public IP addresses.

> **Important:** This lab uses **placeholder project IDs** (`my-producer-project-id` and `my-consumer-project-id`). Replace them with your own Google Cloud project IDs in a local `terraform.tfvars` file (ignored by `.gitignore`). Never commit real project IDs, state files, or credentials.

---

## Architecture Overview

```text
+------------------------------------------+       +------------------------------------------+
|  CONSUMER PROJECT                        |       |  PRODUCER PROJECT                        |
|  VPC: psc-consumer-vpc                   |       |  VPC: psc-producer-vpc                   |
|                                          |       |                                          |
|  Subnet: 10.10.1.0/24                    |       |  NAT Subnet (PRIVATE_SERVICE_CONNECT)    |
|  +-----------------+   +---------------+ |       |  10.10.2.0/28 (12 usable SNAT IPs)       |
|  | Client VM       |-->| PSC Endpoint  |========>|  Service Attachment (ACCEPT_MANUAL)      |
|  | (no public IP)  |   | 10.10.1.50    | |  PSC  |         |                                |
|  +-----------------+   +---------------+ |       |         v                                |
|          |                               |       |  Internal Passthrough NLB (TCP/80)       |
|          v                               |       |         |                                |
|  Cloud DNS Private Zone                  |       |         v                                |
|  app.psc-lab.internal -> 10.10.1.50      |       |  Backend Subnet: 10.10.1.0/24            |
|                                          |       |  Backend VM (HTTP/80 responder)          |
+------------------------------------------+       +------------------------------------------+
```

---

## Official Sources

All architecture behavior, limits, IAM roles, DNS options, and commands in this lab are verified against official Google Cloud documentation:

1. **Private Service Connect overview:** https://cloud.google.com/vpc/docs/private-service-connect
2. **About published services:** https://cloud.google.com/vpc/docs/about-vpc-hosted-services
3. **Publish services by using Private Service Connect (producer):** https://cloud.google.com/vpc/docs/configure-private-service-connect-producer
4. **About accessing published services through endpoints:** https://cloud.google.com/vpc/docs/about-accessing-vpc-hosted-services-endpoints
5. **Access published services through endpoints (consumer):** https://cloud.google.com/vpc/docs/configure-private-service-connect-services
6. **Private Service Connect security (IAM, accept/reject lists, org policies):** https://cloud.google.com/vpc/docs/private-service-connect-security
7. **VPC quotas and limits (PSC):** https://cloud.google.com/vpc/docs/quota

---

## Prerequisites

- Two Google Cloud projects (or two separate VPC networks in one project if you set both variables to the same project ID—note that the consumer endpoint and producer service attachment **cannot** be in the same VPC network).
- Enabled APIs in both projects:
  - `compute.googleapis.com` (Compute Engine API)
  - `dns.googleapis.com` (Cloud DNS API — consumer project)
  - `servicedirectory.googleapis.com` (Service Directory API — consumer project, required for automatic DNS)
- IAM roles:
  - Producer project: `roles/compute.networkAdmin` (and `roles/compute.instanceAdmin.v1` / `roles/compute.securityAdmin` for the sample backend VM and firewalls).
  - Consumer project: `roles/compute.networkAdmin`, `roles/dns.admin`, and `roles/servicedirectory.editor` (for automatic DNS registration).
- Terraform `>= 1.5.0` and `gcloud` CLI authenticated (`gcloud auth application-default login`).

---

## Quick Start (Terraform)

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real producer_project_id and consumer_project_id

terraform init
terraform plan
terraform apply
```

### Verify Connectivity & SNAT Translation

1. Check the consumer endpoint status:
   ```bash
   gcloud compute forwarding-rules describe psc-consumer-endpoint \
     --project=<CONSUMER_PROJECT_ID> \
     --region=us-central1 \
     --format="yaml(IPAddress,pscConnectionId,pscConnectionStatus,target)"
   ```
   Confirm `pscConnectionStatus: ACCEPTED`.

2. Check the allocated producer NAT IP:
   ```bash
   gcloud compute service-attachments describe psc-producer-sa \
     --project=<PRODUCER_PROJECT_ID> \
     --region=us-central1 \
     --show-nat-ips
   ```

3. SSH into the consumer client VM via Identity-Aware Proxy (IAP) and query the private DNS name:
   ```bash
   gcloud compute ssh psc-consumer-client-1 \
     --project=<CONSUMER_PROJECT_ID> \
     --zone=us-central1-a \
     --tunnel-through-iap

   # Inside the consumer VM:
   dig +short app.psc-lab.internal
   curl -s http://app.psc-lab.internal/
   ```
   Notice that `Client Source IP (Producer View)` is an address inside **`10.10.2.0/28`** (the producer PSC NAT subnet), NOT the consumer VM's `10.10.1.x` IP!

---

## Access Control Failure Demos (PENDING and REJECTED)

1. **Test `PENDING` state:** In `terraform.tfvars`, set `accept_consumer_project = false` and run `terraform apply`. Because `reconcile_connections = true`, the endpoint transitions from `ACCEPTED` to `PENDING` and `curl` from the consumer VM times out.
2. **Test `REJECTED` state:** Set `reject_consumer_project = true` and run `terraform apply`. The consumer project is placed on `consumer_reject_lists`, and `pscConnectionStatus` transitions to `REJECTED`.
3. **Restore:** Set `accept_consumer_project = true` and `reject_consumer_project = false`, then `terraform apply`.

---

## Equivalent `gcloud` CLI Walkthrough

See [`gcloud-lab.sh`](gcloud-lab.sh) for the complete step-by-step `gcloud` commands.

---

## Tear-Down & Cleanup

Always destroy the **consumer endpoint before the producer service attachment** (if you delete the service attachment first, the consumer endpoint enters the terminal `CLOSED` state and still counts toward producer VPC quotas until deleted).

With Terraform:
```bash
terraform destroy
```

If using `gcloud`, delete consumer resources first (DNS records & zone, client VM, PSC forwarding rule, static IP, subnet, VPC), then delete producer resources (service attachment, ILB forwarding rule, backend service, health check, instance group, backend VM, firewalls, NAT subnet, backend subnet, VPC).
