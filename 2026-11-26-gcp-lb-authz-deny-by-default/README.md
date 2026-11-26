# Practice Lab: Google Cloud Load Balancing `DENY_BY_DEFAULT` Authorization Policies

This hands-on lab deploys a **regional internal Application Load Balancer (`INTERNAL_MANAGED`)**, attaches a `DENY_BY_DEFAULT` authorization policy with `gcloud network-security authz-policies import`, verifies default-deny behavior, layers an `ALLOW` policy for a specific service account and path (`/api/payments`), and tears everything down cleanly so charges stop.

## Official Google Cloud Documentation
- Authorization policy overview: https://docs.cloud.google.com/load-balancing/docs/auth-policy/auth-policy-overview
- Set up authorization policies for Application Load Balancers: https://docs.cloud.google.com/load-balancing/docs/auth-policy/set-up-auth-policy-app-lb
- AuthzPolicy REST resource (`v1beta1`): https://docs.cloud.google.com/load-balancing/docs/reference/network-security/rest/v1beta1/projects.locations.authzPolicies
- Google Cloud release notes (`DENY_BY_DEFAULT` GA, November 19, 2026): https://docs.cloud.google.com/release-notes
- `gcloud network-security authz-policies import` reference: https://cloud.google.com/sdk/gcloud/reference/network-security/authz-policies/import

## Prerequisites
- A Google Cloud project with billing enabled and permissions to create Compute Engine, IAM Service Account, and Network Security `AuthzPolicy` resources.
- Terraform >= 1.5 and the Google Cloud CLI (`gcloud`) authenticated to your project.
- The Terraform configuration enables `compute.googleapis.com`, `networksecurity.googleapis.com`, and `networkservices.googleapis.com`.

## Step 1: Configure Variables and Deploy the Internal ALB

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your own project_id (never commit terraform.tfvars)

terraform init
terraform apply
```

Record the Terraform outputs:

```bash
export PROJECT_ID=$(terraform output -raw forwarding_rule_self_link | awk -F'/' '{print $7}')
export REGION="us-central1"
export FR_NAME=$(terraform output -raw forwarding_rule_name)
export ALB_IP=$(terraform output -raw internal_alb_ip)
export CLIENT_SA=$(terraform output -raw client_service_account_email)
```

## Step 2: Confirm Default-Allow Baseline (Before AuthzPolicy)

Connect to the client VM via IAP SSH (use the `ssh_client_command` output) and test both endpoints:

```bash
curl -i http://$ALB_IP/api/payments
curl -i http://$ALB_IP/api/admin
```

With no authorization policies attached, both requests succeed (`200 OK`).

## Step 3: Import the `DENY_BY_DEFAULT` Policy

Render `policies/authz-policy-deny-by-default.yaml` from the template (replacing `PROJECT_ID`, `REGION`, and `FORWARDING_RULE_NAME`) and import it:

```bash
sed -e "s|PROJECT_ID|$PROJECT_ID|g" \
    -e "s|REGION|$REGION|g" \
    -e "s|FORWARDING_RULE_NAME|$FR_NAME|g" \
    policies/authz-policy-deny-by-default.yaml.tpl > policies/authz-policy-deny-by-default.yaml

gcloud network-security authz-policies import authz-lab-deny-by-default \
  --source=policies/authz-policy-deny-by-default.yaml \
  --location="$REGION" \
  --project="$PROJECT_ID"
```

Verify the policy is active:

```bash
gcloud network-security authz-policies describe authz-lab-deny-by-default \
  --location="$REGION" \
  --project="$PROJECT_ID"
```

Re-run `curl` from the client VM against `/api/payments` and `/api/admin`. Both requests are now rejected by the `DENY_BY_DEFAULT` baseline, and Cloud Logging records `jsonPayload.proxyStatus="denied_by_authz_policy"` and `jsonPayload.authzPolicyInfo.policies.details="denied_by_default"`.

## Step 4: Layer a Companion `ALLOW` Policy

Render `policies/authz-policy-allow-payments.yaml` from the template (allowing only `CLIENT_SA` to reach `/api/payments`) and import it:

```bash
sed -e "s|PROJECT_ID|$PROJECT_ID|g" \
    -e "s|REGION|$REGION|g" \
    -e "s|FORWARDING_RULE_NAME|$FR_NAME|g" \
    -e "s|CLIENT_SA_EMAIL|$CLIENT_SA|g" \
    policies/authz-policy-allow-payments.yaml.tpl > policies/authz-policy-allow-payments.yaml

gcloud network-security authz-policies import authz-lab-allow-payments \
  --source=policies/authz-policy-allow-payments.yaml \
  --location="$REGION" \
  --project="$PROJECT_ID"
```

Re-test from the client VM:
- `curl -i http://$ALB_IP/api/payments` → **Allowed (`200 OK`)** because the client VM's service account and exact path match the `ALLOW` policy.
- `curl -i http://$ALB_IP/api/admin` → **Denied** (`denied_as_no_allow_policies_matched_request` in Cloud Logging).

## Step 5: Inspect Cloud Logging

In Cloud Logging (Logs Explorer), query the regional internal Application Load Balancer logs:

```text
logName="projects/PROJECT_ID/logs/loadbalancing.googleapis.com%2Frequests"
resource.type="internal_http_lb_rule"
(jsonPayload.authzPolicyInfo.policies.details="denied_by_default" OR
 jsonPayload.authzPolicyInfo.policies.details="denied_as_no_allow_policies_matched_request")
```

## Step 6: Teardown and Cleanup (Stop All Charges)

Always delete the `AuthzPolicy` resources first (they reference the forwarding rule), then destroy the Terraform stack:

```bash
gcloud network-security authz-policies delete authz-lab-allow-payments \
  --location="$REGION" --project="$PROJECT_ID" --quiet

gcloud network-security authz-policies delete authz-lab-deny-by-default \
  --location="$REGION" --project="$PROJECT_ID" --quiet

terraform destroy
```

Remove rendered local YAML files and `terraform.tfvars` if you no longer need them.
