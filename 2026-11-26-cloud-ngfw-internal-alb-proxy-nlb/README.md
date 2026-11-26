# Cloud NGFW Practice Lab: Protecting Internal Application & Proxy Network Load Balancers

This practice lab lets you deploy and test **Cloud Next Generation Firewall (Cloud NGFW)** ingress protection on the managed Envoy proxies in a **proxy-only subnet** for:

- A **Regional Internal Application Load Balancer** (`INTERNAL_MANAGED`, HTTP on port `80`)
- An optional **Regional Internal Proxy Network Load Balancer** (`INTERNAL_MANAGED`, TCP on port `8080`, toggled with `enable_proxy_nlb = true`)

You will attach a **Regional Network Firewall Policy** to the VPC network with `--target-type=INTERNAL_MANAGED_LB` rules that:
1. Allow Google's managed Envoy frontend health-check probes (`35.191.0.0/16`)
2. Allow an approved client VM (`client-allowed`)
3. Deny all other ingress traffic (`0.0.0.0/0`) to the load balancer forwarding rule(s), with firewall logging enabled

You can test the exact same allow vs. deny behavior from two client VMs (`client-allowed` and `client-blocked`), inspect Cloud Logging, and then tear everything down cleanly so charges stop.

## Official Google Cloud Sources

- Cloud NGFW release notes: https://cloud.google.com/firewall/docs/release-notes
- Firewall endpoints overview: https://cloud.google.com/firewall/docs/about-firewall-endpoints
- Use global network firewall policies to protect Envoy-based load balancers: https://cloud.google.com/firewall/docs/global-network-app-lb
- Use regional network firewall policies to protect internal Application Load Balancers and internal proxy Network Load Balancers: https://cloud.google.com/firewall/docs/regional-network-app-lb
- Cloud NGFW overview & supported load balancers: https://cloud.google.com/firewall/docs/about-firewalls
- Firewall policy rule details (`INTERNAL_MANAGED_LB`): https://cloud.google.com/firewall/docs/firewall-policies-rule-details
- Health checks overview (probe IP ranges): https://cloud.google.com/load-balancing/docs/health-check-concepts
- Proxy-only subnets for Envoy-based load balancers: https://cloud.google.com/load-balancing/docs/proxy-only-subnets

## Prerequisites

- A Google Cloud project with billing enabled and Compute Engine API (`compute.googleapis.com`) enabled
- IAM permissions to create VPC networks, subnets, Compute Engine VMs, internal load balancers, and regional network firewall policies (e.g., `roles/compute.networkAdmin`, `roles/compute.securityAdmin`, `roles/compute.instanceAdmin.v1`)
- Terraform `>= 1.5` and/or Google Cloud CLI (`gcloud`)
- Never commit `terraform.tfvars`, `.terraform/`, `*.tfstate`, or credentials to version control

## Quick Start (Terraform)

1. Copy the example variables file and fill in your own project ID:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Initialize, review, and apply:

```bash
terraform init
terraform plan
terraform apply
```

3. Note the Terraform outputs:
   - `internal_alb_ip` — IP address of the regional internal Application Load Balancer forwarding rule
   - `internal_alb_forwarding_rule_ref` — Forwarding rule path used by `--target-forwarding-rules`
   - `internal_proxy_nlb_ip` — IP address of the regional internal proxy Network Load Balancer (when `enable_proxy_nlb = true`)

## Verify Allow vs. Deny Traffic

Wait 1–2 minutes after `terraform apply` for the backend startup script and health checks to report healthy, then test via IAP SSH:

### 1. Test from the Approved Client VM (Expected: HTTP 200 OK)

```bash
gcloud compute ssh client-allowed \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="curl -sS -i --max-time 5 http://<INTERNAL_ALB_IP>"
```

Expected result: HTTP `200 OK` with a response identifying the backend VM.

### 2. Test from the Unapproved Client VM (Expected: Blocked / Timeout)

```bash
gcloud compute ssh client-blocked \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="curl -sS -i --max-time 5 http://<INTERNAL_ALB_IP>"
```

Expected result: Connection timed out (`curl: (28) Connection timed out`) because the Cloud NGFW `INTERNAL_MANAGED_LB` baseline deny rule (`priority 2000`, `0.0.0.0/0`) drops packets before Envoy forwards them to the backend.

### 3. Verify Firewall Policy Logs in Cloud Logging

```bash
gcloud logging read \
  'resource.type="gce_subnetwork" OR logName:"compute.googleapis.com%2Ffirewall"' \
  --limit=20 \
  --format="table(timestamp, jsonPayload.disposition, jsonPayload.rule_details.reference, jsonPayload.connection.src_ip, jsonPayload.connection.dest_ip)"
```

Look for `ALLOWED` entries from `client-allowed` and `DENIED` entries from `client-blocked` referencing your regional network firewall policy.

## Equivalent `gcloud` Commands

See [`gcloud-commands.sh`](gcloud-commands.sh) for the standalone `gcloud` CLI workflow that creates the regional network firewall policy, associates it with the VPC, adds the `INTERNAL_MANAGED_LB` rules (including the `35.191.0.0/16` health-check probe allow rule, approved client allow rule, and `0.0.0.0/0` deny baseline), and shows how to switch to a global network firewall policy.

## Destroy & Cleanup (Stop All Charges)

When you are finished testing, destroy all lab resources immediately:

```bash
terraform destroy
```

### Important Proxy-Only Subnet Deletion Note

Per Google Cloud documentation, an `ACTIVE` proxy-only subnet cannot be deleted while any regional Envoy-based load balancer forwarding rule still exists in that region and VPC network, or while a `BACKUP` proxy-only subnet exists. Terraform handles dependency order automatically during `terraform destroy`. If you created resources manually with `gcloud`, delete resources in this order:
1. Forwarding rules, target proxies, URL maps, backend services, health checks, and instance groups
2. Firewall policy associations and the network firewall policy
3. Backup proxy-only subnet (if any), then the `ACTIVE` proxy-only subnet
4. Remaining subnets and the VPC network
