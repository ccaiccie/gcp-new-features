# Practice Lab: Private Google Access vs Private Service Connect for Google APIs

This compact Terraform and `gcloud` lab lets you deploy and compare **Private Google Access (PGA)** and a **Private Service Connect (PSC) endpoint for Google APIs** in your own Google Cloud project — using a private Compute Engine VM with **no external IP address**.

Intended public repository path:
`https://github.com/ccaiccie/gcp-new-features/tree/main/2026-11-25-private-google-access-vs-psc`

## What This Lab Deploys

1. **Custom-mode VPC** (`pga-psc-lab-vpc`) with two subnets in your chosen region:
   - `pga-enabled-subnet` (`10.50.1.0/24`) with `private_ip_google_access = true`
   - `pga-disabled-subnet` (`10.50.2.0/24`) with `private_ip_google_access = false` (for optional blocked-path testing)
2. **PGA routing & DNS**:
   - Custom static route for `199.36.153.8/30` (`private.googleapis.com` VIP range) and `34.126.0.0/18` (direct connectivity) with next hop `default-internet-gateway`
   - Egress allow firewall rule for the PGA VIP and PSC endpoint IP (plus IAP SSH ingress rule from `35.235.240.0/20` so you can SSH into the private VM without an external IP)
   - Cloud DNS private zone for `googleapis.com` pointing `private.googleapis.com` to `199.36.153.8..11` (and optional CNAME or PSC override)
3. **Private Service Connect endpoint for Google APIs**:
   - Global internal IPv4 address (`10.50.250.5`, outside all subnet ranges) with `purpose = "PRIVATE_SERVICE_CONNECT"`
   - Global forwarding rule targeting the `all-apis` bundle (switchable to `vpc-sc` via `psc_api_bundle`)
   - Private Cloud DNS zone (`p.googleapis.com`) with an A record (`storage-labpsc.p.googleapis.com` -> `10.50.250.5`)
4. **Private Compute Engine VM** (`pga-psc-test-vm`, `e2-micro`, **no external IP**) in `pga-enabled-subnet`.

## Prerequisites

- Google Cloud project with billing enabled and Compute Engine + Cloud DNS APIs enabled:
  ```bash
  gcloud services enable compute.googleapis.com dns.googleapis.com storage.googleapis.com
  ```
- Terraform `>= 1.6` and `gcloud` CLI authenticated (`gcloud auth login` and `gcloud auth application-default login`).
- IAM roles such as Compute Network Admin (`roles/compute.networkAdmin`), Compute Instance Admin, and DNS Administrator (`roles/dns.admin`).

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your real project_id

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Verify Reachability From the Private VM

1. **SSH to the private VM via Identity-Aware Proxy (no external IP needed):**
   ```bash
   gcloud compute ssh pga-psc-test-vm \
     --zone="$(terraform output -raw vm_zone)" \
     --tunnel-through-iap
   ```
2. **Verify Private Google Access (`private.googleapis.com`):**
   ```bash
   dig +short private.googleapis.com
   # Expect 199.36.153.8..11
   curl -sI https://storage.googleapis.com/generate_204
   # Expect HTTP/2 204 (or HTTP/1.1 204)
   ```
3. **Verify the Private Service Connect endpoint (official Google Cloud check):**
   ```bash
   # PSC endpoints do not respond to ICMP ping; use HTTP /generate_204
   curl -v http://10.50.250.5/generate_204
   # Expect HTTP/1.1 204 No Content

   dig +short storage-labpsc.p.googleapis.com
   # Expect 10.50.250.5
   curl -sI https://storage-labpsc.p.googleapis.com/generate_204
   # Expect HTTP 204 via your internal PSC endpoint IP
   ```
4. **Optional blocked-path test:** Temporarily disable PGA on `pga-enabled-subnet` (`gcloud compute networks subnets update ... --no-enable-private-ip-google-access`) and re-run `curl` to `storage.googleapis.com` (times out), while `curl -v http://10.50.250.5/generate_204` through the PSC endpoint still succeeds!

## Destroy & Clean Up

Always destroy all lab resources when finished so you do not leave VMs, forwarding rules, static addresses, or DNS zones running:

```bash
terraform destroy
```

Confirm cleanup:
```bash
gcloud compute forwarding-rules list --global --filter="name~labpsc"
gcloud compute networks list --filter="name=pga-psc-lab-vpc"
```

## Official Google Cloud Sources

- Private Google Access overview: https://cloud.google.com/vpc/docs/private-google-access
- Configure Private Google Access: https://cloud.google.com/vpc/docs/configure-private-google-access
- Private access options for services: https://cloud.google.com/vpc/docs/private-access-options
- Configure Private Service Connect for Google APIs: https://cloud.google.com/vpc/docs/configure-private-service-connect-apis
- About accessing global Google APIs through endpoints: https://cloud.google.com/vpc/docs/about-accessing-google-apis-endpoints
- Access regional and multi-regional Google APIs through endpoints: https://cloud.google.com/vpc/docs/access-regional-google-apis-endpoints
- Cloud NAT overview: https://cloud.google.com/nat/docs/overview
