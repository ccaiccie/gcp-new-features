# Google Cloud Certificate Manager and Certificate Maps Lab

This practice lab provisions a **Google-managed TLS certificate** with **DNS authorization**, attaches it to a **Certificate Map** with exact, wildcard, and primary map entries, and binds that map to a **Global external Application Load Balancer** target HTTPS proxy using Terraform (with equivalent `gcloud` commands below).

> **COST WARNING:** Global external Application Load Balancers, forwarding rules, and unused reserved static IP addresses **bill until they are deleted**. Run `terraform destroy` (or the `gcloud` cleanup commands) as soon as you finish testing.

## Official Google Cloud Documentation Sources
- Certificate Manager overview: https://cloud.google.com/certificate-manager/docs/overview
- Manage certificates: https://cloud.google.com/certificate-manager/docs/certificates
- Core components of Certificate Manager: https://cloud.google.com/certificate-manager/docs/core-components
- How Certificate Manager works (certificate selection logic): https://cloud.google.com/certificate-manager/docs/certificate-selection-logic
- Domain authorization types: https://cloud.google.com/certificate-manager/docs/domain-authorization
- Manage certificate maps: https://cloud.google.com/certificate-manager/docs/maps
- Manage certificate map entries: https://cloud.google.com/certificate-manager/docs/map-entries
- Deploy a global Google-managed certificate with DNS authorization: https://cloud.google.com/certificate-manager/docs/deploy-google-managed-dns-auth
- Quotas and limits: https://cloud.google.com/certificate-manager/docs/quotas
- Certificate Manager pricing: https://cloud.google.com/certificate-manager/pricing

## Prerequisites
1. A Google Cloud project with billing enabled.
2. Enable the required APIs:
   ```bash
   gcloud services enable certificatemanager.googleapis.com compute.googleapis.com
   ```
3. IAM roles:
   - `roles/certificatemanager.owner` (or `roles/certificatemanager.editor`)
   - `roles/compute.loadBalancerAdmin` (or `roles/compute.networkAdmin`)
   - `roles/dns.admin` (if using Cloud DNS)
4. A public domain name (FQDN) you control so you can add the validation `CNAME` record.
5. Terraform 1.5+ and the Google Cloud CLI (`gcloud`) authenticated (`gcloud auth application-default login`).

## Option A: Deploy with Terraform

1. Copy the example variables file and fill in your project ID and domain:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
3. Read the DNS authorization CNAME output:
   ```bash
   terraform output dns_authorization_cname
   ```
   If `create_cloud_dns_record = false`, add that `CNAME` record in your external DNS provider.
   **Important:** Ensure the `CNAME` is the **only** resource record at that validation DNS name (do not mix `CNAME` and `TXT` on the same name). Keep the `CNAME` in place so Certificate Manager can renew the certificate automatically.

## Option B: Equivalent `gcloud` Commands

```bash
export PROJECT_ID="your-gcp-project-id"
export DOMAIN="app.example.com"

# 1. Create DNS authorization
gcloud certificate-manager dns-authorizations create cm-lab-dns-auth \
  --domain="${DOMAIN}" \
  --type=FIXED_RECORD

# 2. Inspect the CNAME record to publish in your DNS zone
gcloud certificate-manager dns-authorizations describe cm-lab-dns-auth

# 3. Create the Google-managed certificate (covers root and wildcard)
gcloud certificate-manager certificates create cm-lab-managed-cert \
  --domains="${DOMAIN},*.${DOMAIN}" \
  --dns-authorizations="cm-lab-dns-auth"

# 4. Create the certificate map
gcloud certificate-manager maps create cm-lab-cert-map

# 5. Add exact, wildcard, and primary certificate map entries
gcloud certificate-manager maps entries create cm-lab-entry-exact \
  --map="cm-lab-cert-map" \
  --certificates="cm-lab-managed-cert" \
  --hostname="${DOMAIN}"

gcloud certificate-manager maps entries create cm-lab-entry-wildcard \
  --map="cm-lab-cert-map" \
  --certificates="cm-lab-managed-cert" \
  --hostname="*.${DOMAIN}"

gcloud certificate-manager maps entries create cm-lab-entry-primary \
  --map="cm-lab-cert-map" \
  --certificates="cm-lab-managed-cert" \
  --set-primary

# 6. Attach the certificate map to an existing target HTTPS proxy
gcloud compute target-https-proxies update cm-lab-https-proxy \
  --certificate-map="cm-lab-cert-map" \
  --global
```

## Verification

1. **Confirm the certificate is `ACTIVE` and domain is `AUTHORIZED`:**
   ```bash
   gcloud certificate-manager certificates describe cm-lab-managed-cert
   ```
   Look for `managed.state: ACTIVE` and `authorizationAttemptInfo[].state: AUTHORIZED`.
2. **Confirm certificate map entries are `ACTIVE`:**
   ```bash
   gcloud certificate-manager maps entries describe cm-lab-entry-exact --map="cm-lab-cert-map"
   gcloud certificate-manager maps entries describe cm-lab-entry-wildcard --map="cm-lab-cert-map"
   ```
3. **Confirm the target HTTPS proxy references the certificate map:**
   ```bash
   gcloud compute target-https-proxies list
   ```
4. **Test the TLS handshake and SNI selection against the load balancer IP:**
   ```bash
   LB_IP=$(terraform output -raw load_balancer_ip)
   openssl s_client -connect "${LB_IP}:443" -servername "app.example.com" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
   openssl s_client -connect "${LB_IP}:443" -servername "api.app.example.com" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
   ```

## Tear-Down / Destroy Everything (Stop Billing)

### If deployed with Terraform:
```bash
terraform destroy
```
Verify no reserved IP addresses or forwarding rules remain:
```bash
gcloud compute forwarding-rules list --global
gcloud compute addresses list --global
```
If you manually added the validation `CNAME` record in an external DNS provider, remove it if you also want to revoke Certificate Manager's renewal permission for that domain.

### If deployed with `gcloud`:
```bash
# Delete forwarding rule and target HTTPS proxy first (or detach map if keeping proxy)
gcloud compute forwarding-rules delete cm-lab-https-fr --global --quiet
gcloud compute target-https-proxies delete cm-lab-https-proxy --global --quiet
gcloud compute url-maps delete cm-lab-url-map --global --quiet
gcloud compute backend-services delete cm-lab-backend --global --quiet
gcloud compute health-checks delete cm-lab-hc --global --quiet
gcloud compute addresses delete cm-lab-lb-ip --global --quiet

# Delete Certificate Manager entries, map, certificate, and DNS authorization
gcloud certificate-manager maps entries delete cm-lab-entry-exact --map="cm-lab-cert-map" --quiet
gcloud certificate-manager maps entries delete cm-lab-entry-wildcard --map="cm-lab-cert-map" --quiet
gcloud certificate-manager maps entries delete cm-lab-entry-primary --map="cm-lab-cert-map" --quiet
gcloud certificate-manager maps delete cm-lab-cert-map --quiet
gcloud certificate-manager certificates delete cm-lab-managed-cert --quiet
gcloud certificate-manager dns-authorizations delete cm-lab-dns-auth --quiet
```
