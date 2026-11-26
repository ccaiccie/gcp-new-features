# Google Cloud NGFW URL Filtering (Domain & SNI) Practice Lab

Hands-on Terraform and `gcloud` lab for the **Network Technician** YouTube channel (`gcp new features` playlist).

## What This Lab Builds
- Custom-mode VPC (`urlf-lab-vpc`, MTU `1460` to match a standard firewall endpoint) and subnet (`10.10.0.0/24`)
- Cloud Router + Cloud NAT gateway for private VM outbound internet egress
- Private Debian 12 test VM (`urlf-lab-client`) with **no public IPv4 address** (accessed via Identity-Aware Proxy SSH)
- Cloud NGFW **URL filtering security profile** (`URL_FILTERING`) with:
  - Priority `500` `DENY`: `*example.org`
  - Priority `1000` `ALLOW`: `*example.com`
  - Implicit `DENY` `*` at priority `2147483647` (automatically enforced by Cloud NGFW)
- **Security profile group** wrapping the URL filtering profile
- Zonal **Cloud NGFW firewall endpoint** + VPC endpoint association in the same zone as the test VM
- **Global network firewall policy** with:
  - Priority `100` `INGRESS` `ALLOW` from `35.235.240.0/20` on TCP `22` (IAP SSH)
  - Priority `200` `EGRESS` `apply_security_profile_group` to `0.0.0.0/0` on TCP `80, 443` with logging enabled

## Prerequisites
- A Google Cloud project with billing enabled (Cloud NGFW firewall endpoints incur hourly and data-processing charges; tear down when finished)
- Required IAM roles (project-level scope or organization-level scope):
  - `roles/compute.networkAdmin` (or `roles/networksecurity.firewallEndpointAdmin` and `roles/networksecurity.securityProfileAdmin`)
  - `roles/compute.securityAdmin`
  - `roles/iap.tunnelResourceAccessor` (to SSH via IAP)
- Terraform >= 1.6.0 and Google Cloud CLI (`gcloud`)

## Option A: Deploy with Terraform
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your own project_id (never commit terraform.tfvars)
terraform init
terraform plan
terraform apply
```

> Note: Creating a Cloud NGFW firewall endpoint and its VPC association takes several minutes to transition from `CREATING` to `ACTIVE`.

## Option B: Deploy with gcloud CLI
```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
bash gcloud-deploy.sh
```

## Verify Allowed vs. Blocked Domain and SNI
1. SSH into the private VM through IAP:
   ```bash
   gcloud compute ssh urlf-lab-client --zone=us-central1-a --project=your-gcp-project-id --tunnel-through-iap
   ```
2. Test an **allowed** domain over HTTP (`Host` header) and HTTPS (TLS `SNI`):
   ```bash
   curl -I -m 5 http://example.com
   curl -I -m 5 https://example.com
   ```
   Both succeed because `*example.com` matches priority `1000` (`ALLOW`).
3. Test an **explicitly denied** domain over HTTP and HTTPS:
   ```bash
   curl -I -m 5 http://example.org
   curl -I -m 5 https://example.org
   ```
   Both fail / reset because `*example.org` matches priority `500` (`DENY`).
4. Test a **non-matching** domain (hits the implicit `DENY` `*` filter at priority `2147483647`):
   ```bash
   curl -I -m 5 https://example.net
   ```
5. Inspect URL filtering logs in **Logs Explorer**:
   ```text
   resource.type="networksecurity.googleapis.com/FirewallEndpoint"
   logName="projects/your-gcp-project-id/logs/networksecurity.googleapis.com%2Ffirewall_url_filter"
   ```
   Verify `jsonPayload.action` (`ALLOW` vs `DENY`), `jsonPayload.denyType` (`HOST` vs `SNI`), `jsonPayload.uriMatched`, `jsonPayload.applicationLayerDetails.uri`, and `jsonPayload.sessionLayerDetails.sni`.

## Tear Down / Cleanup (Stop Charges)
### Terraform
```bash
terraform destroy
```
### gcloud CLI
```bash
export PROJECT_ID="your-gcp-project-id"
bash gcloud-cleanup.sh
```

## Official Google Cloud Documentation
- URL filtering service overview: https://cloud.google.com/firewall/docs/about-url-filtering
- Cloud NGFW release notes: https://cloud.google.com/firewall/docs/release-notes
- Configure the URL filtering service: https://cloud.google.com/firewall/docs/configure-url-filtering
- Create and manage URL filtering security profiles: https://cloud.google.com/firewall/docs/configure-urlf-security-profiles
- Security profile overview: https://cloud.google.com/firewall/docs/about-security-profiles
- Security profile group overview: https://cloud.google.com/firewall/docs/about-security-profile-groups
- URL filtering logs: https://cloud.google.com/firewall/docs/url-filtering-logs
- Set up the URL filtering service tutorial: https://cloud.google.com/firewall/docs/tutorials/set-up-urlf-tutorial
