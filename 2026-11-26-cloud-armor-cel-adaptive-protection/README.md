# Practice Lab: Google Cloud Armor Custom CEL Rules & Adaptive Protection

This compact Terraform and `gcloud` lab deploys a **global external Application Load Balancer** with a simple Nginx backend and attaches a **Google Cloud Armor security policy** with custom CEL `request.params` and `request.body` deny rules, verbose logging, and **Adaptive Protection** enabled.

Intended public repository path:
`https://github.com/ccaiccie/gcp-new-features/tree/main/2026-11-26-cloud-armor-cel-adaptive-protection`

## What This Lab Deploys

1. **Global External Application Load Balancer (`EXTERNAL_MANAGED`)** with a global static IPv4 address, URL map, target HTTP proxy, backend service (with request logging enabled), and a tiny `e2-micro` Nginx backend VM that returns `200 OK` on both `GET` and `POST` requests.
2. **Cloud Armor Security Policy (`armor-cel-lab-policy`)** attached to the backend service with:
   - `advanced_options_config`: `log_level = "VERBOSE"`, `json_parsing = "STANDARD"`
   - `adaptive_protection_config`: Layer 7 DDoS defense enabled (`enable = true`)
   - **Priority 1000 (CEL `request.params` rule):** `has(request.params.password) && request.params.password.contains('123')` -> `deny(403)`
   - **Priority 1100 (CEL `request.body` rule):** `request.method == 'POST' && request.body.contains('malicious-value')` -> `deny(403)`
   - **Priority 2147483647 (Default rule):** `allow`

## Honest Note on Adaptive Protection in a Small Lab

- Adaptive Protection requires at least **1 hour** of baseline training per backend service and detects anomalous high-volume Layer 7 traffic (such as HTTP floods). **Never simulate a DDoS attack against a public endpoint.**
- Full alerts with an attack signature and `evaluateAdaptiveProtection('<alertId>')` suggested rule require **Google Cloud Armor Enterprise**; without Enterprise, only basic alerts (confidence score + attack size) are generated.
- This lab enables Adaptive Protection cleanly on the policy and includes the exact `gcloud` preview-mode command you would run when a real alert appears in the Adaptive Protection dashboard or Cloud Logging.

## Prerequisites

- Google Cloud project with Compute Engine API enabled:
  ```bash
  gcloud services enable compute.googleapis.com logging.googleapis.com
  ```
- Terraform `>= 1.6` and `gcloud` CLI authenticated (`gcloud auth login` and `gcloud auth application-default login`).

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your real project_id

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Wait ~2–3 minutes for the global external ALB and backend health check to become healthy, then grab the load balancer IP:
```bash
LB_IP=$(terraform output -raw load_balancer_ip)
```

## Safe Verification Tests (Allow vs CEL Block + Cloud Logging)

1. **Allowed JSON POST (misses both CEL deny rules -> expect HTTP 200):**
   ```bash
   curl -i -X POST "http://${LB_IP}/api/login" \
     -H "Content-Type: application/json" \
     -d '{"username":"mike","password":"strong-value"}'
   ```
2. **Blocked by CEL `request.params` rule (JSON parsed -> expect HTTP 403):**
   ```bash
   curl -i -X POST "http://${LB_IP}/api/login" \
     -H "Content-Type: application/json" \
     -d '{"username":"mike","password":"test123value"}'
   ```
3. **Blocked by CEL `request.body` rule (raw body match -> expect HTTP 403):**
   ```bash
   curl -i -X POST "http://${LB_IP}/api/submit" \
     -H "Content-Type: text/plain" \
     -d 'payload with malicious-value inside'
   ```
4. **Inspect Cloud Logging (`enforcedSecurityPolicy`):**
   ```bash
   gcloud logging read \
     'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.name="armor-cel-lab-policy"' \
     --limit=10 --format="table(timestamp,httpRequest.status,jsonPayload.enforcedSecurityPolicy.outcome,jsonPayload.enforcedSecurityPolicy.priority)"
   ```
5. **Reference command when a real Adaptive Protection alert ID arrives (Preview -> Enforce):**
   ```bash
   # Deploy suggested rule in PREVIEW mode first (logs under previewSecurityPolicy without blocking):
   gcloud compute security-policies rules create 500 \
     --security-policy="armor-cel-lab-policy" \
     --expression="evaluateAdaptiveProtection('REPLACE_WITH_ALERT_ID')" \
     --action="deny-403" \
     --preview
   ```

## Destroy & Clean Up

Always destroy the lab when done so Load Balancer forwarding rule, static IP, VM, and Cloud Armor charges stop:

```bash
terraform destroy
```

Confirm cleanup:
```bash
gcloud compute security-policies list --filter="name=armor-cel-lab-policy"
gcloud compute forwarding-rules list --global --filter="name~armor-cel-lab"
```

## Official Google Cloud Sources

- Cloud Armor custom rules language reference: https://cloud.google.com/armor/docs/rules-language-reference
- Adaptive Protection overview: https://cloud.google.com/armor/docs/adaptive-protection-overview
- Create security policy rules: https://cloud.google.com/armor/docs/create-security-policy-rules
- Security policy overview: https://cloud.google.com/armor/docs/security-policy-overview
- Using request logging: https://cloud.google.com/armor/docs/request-logging
