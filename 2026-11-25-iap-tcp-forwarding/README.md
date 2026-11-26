# Practice Lab — Google Cloud Identity-Aware Proxy (IAP) & IAP TCP Forwarding

Intended repository path: `ccaiccie/gcp-new-features/2026-11-25-iap-tcp-forwarding`

This Terraform and `gcloud` practice lab deploys:
1. A custom VPC with **no** `default-allow-ssh` or `default-allow-rdp` rules and an ingress firewall rule allowing TCP ports `22` and `3389` strictly from Google IAP's official IPv4 TCP forwarding range **`35.235.240.0/20`**.
2. A **Compute Engine VM with no external/public IP address**, secured with per-VM **`roles/iap.tunnelResourceAccessor`** (`IAP-secured Tunnel User`) and an IAM condition (`destination.port == 22`).
3. A **Compute Engine HTTPS backend service** with **IAP enabled** and **`roles/iap.httpsResourceAccessor`** (`IAP-secured Web App User`) IAM binding.

## Official Google Cloud Documentation Sources
- Identity-Aware Proxy overview: https://cloud.google.com/iap/docs/concepts-overview
- TCP forwarding overview: https://cloud.google.com/iap/docs/tcp-forwarding-overview
- Use IAP for TCP forwarding: https://cloud.google.com/iap/docs/using-tcp-forwarding
- Enable IAP for Compute Engine: https://cloud.google.com/iap/docs/enabling-compute-howto

## Prerequisites
- A Google Cloud project with billing enabled and APIs enabled (`compute.googleapis.com`, `iap.googleapis.com`).
- IAM permissions to create VPC networks, VMs, backend services, and IAP IAM policies (for example `roles/iap.policyAdmin` + Compute/Network Admin).
- **Terraform >= 1.6** and **Google Cloud CLI (`gcloud`)** authenticated (`gcloud auth login` and `gcloud auth application-default login`).

## 1. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Set project_id, region, zone, and user_member (e.g., "user:mike@example.com")
```

## 2. Deploy with Terraform
```bash
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## 3. Verify with `gcloud`
Confirm the IAP ingress firewall rule allows only `35.235.240.0/20`:
```bash
gcloud compute firewall-rules describe <firewall_rule_name> --project <project_id>
```

Connect to the private VM (which has **no public IP**) over IAP TCP forwarding:
```bash
gcloud compute ssh <vm_name> \
  --zone <zone> \
  --project <project_id> \
  --tunnel-through-iap
```

Or open a local TCP tunnel (for example for RDP on port 3389 or another admin port):
```bash
gcloud compute start-iap-tunnel <vm_name> 3389 \
  --local-host-port=localhost:13389 \
  --zone <zone> \
  --project <project_id>
```

Confirm IAP is enabled on the HTTPS backend service:
```bash
gcloud compute backend-services describe <backend_service_name> --global --project <project_id> --format="value(iap.enabled)"
```

## 4. Destroy & Clean Up
Stop all VM and load-balancer charges cleanly:
```bash
terraform destroy
```
