# Google Cloud Network Intelligence Center Lab: Firewall Insights & Network Analyzer

Practice lab for the Network Technician YouTube lesson on **Google Cloud Network Intelligence Center — Firewall Insights and Network Analyzer** (`gcp new features` playlist).

> **COST WARNING:** Run this lab **only in a disposable Google Cloud project**. Compute Engine VMs, reserved IP addresses, Cloud Logging sinks, and **Firewall Rules Logging** (required for Firewall Insights log-based insights and metrics) can incur charges until deleted or disabled. In addition, Firewall Insights configuration analysis (shadowed rules) and overgranting analysis (log-based overly permissive rules) have published per-rule and per-million-log-entry pricing. See the [official Network Intelligence Center pricing page](https://cloud.google.com/network-intelligence-center/pricing) before enabling paid insight features, and destroy all lab resources as soon as you finish.

> **PRODUCTION SAFETY WARNING:** Tightening or deleting firewall rules based on insights can block production traffic (including load balancer health checks or infrequent batch jobs). Always test changes in a disposable project and verify logs before modifying production rules.

---

## Official Documentation Sources

- **Network Intelligence Center overview:** https://cloud.google.com/network-intelligence-center/docs/concepts/overview (redirects to `https://docs.cloud.google.com/network-intelligence-center/docs/overview`)
- **Firewall Insights overview:** https://cloud.google.com/network-intelligence-center/docs/firewall-insights/concepts/overview
- **Firewall Insights — Enable APIs and features:** https://docs.cloud.google.com/network-intelligence-center/docs/firewall-insights/how-to/enable-api-features
- **Firewall Insights — Categories and states:** https://docs.cloud.google.com/network-intelligence-center/docs/firewall-insights/concepts/insights-categories-states
- **Firewall Insights — Roles and permissions:** https://docs.cloud.google.com/network-intelligence-center/docs/firewall-insights/concepts/roles-permissions
- **Network Analyzer overview:** https://cloud.google.com/network-intelligence-center/docs/network-analyzer/concepts/overview (`https://docs.cloud.google.com/network-intelligence-center/docs/network-analyzer/overview`)
- **Network Analyzer — Insight groups and types:** https://docs.cloud.google.com/network-intelligence-center/docs/network-analyzer/insight-groups-types
- **Network Analyzer — Routes with an invalid next hop:** https://docs.cloud.google.com/network-intelligence-center/docs/network-analyzer/insights/vpc-network/route-invalid-next-hop
- **Network Analyzer — Use the Recommender CLI and API:** https://docs.cloud.google.com/network-intelligence-center/docs/network-analyzer/use-cli-recommender-api
- **Network Intelligence Center pricing:** https://cloud.google.com/network-intelligence-center/pricing

---

## What This Lab Creates

1. **Required APIs enabled:** `compute.googleapis.com`, `firewallinsights.googleapis.com`, `recommender.googleapis.com`, `logging.googleapis.com`, and `monitoring.googleapis.com`.
2. **Custom VPC and subnet:** `nic-lab-vpc` and `nic-lab-subnet` (`10.42.0.0/24`).
3. **Test VM (`nic-lab-vm`):** `e2-micro` instance with `can_ip_forward = false` and network tag `web-lab`.
4. **Intentionally messy firewall rules (with Firewall Rules Logging enabled):**
   - `nic-lab-allow-broad-web` (priority `1000`, `0.0.0.0/0`, TCP `80, 443, 8080-8090`) — overly permissive source IP and port range.
   - `nic-lab-allow-shadowed-web` (priority `1100`, `10.42.0.0/24`, TCP `80`) — shadowed by `nic-lab-allow-broad-web`.
   - `nic-lab-allow-unused-legacy` (priority `1000`, `10.99.0.0/24`, TCP `9000`) — allow rule with no hits.
   - `nic-lab-deny-telnet` (priority `900`, `0.0.0.0/0`, TCP `23`) — deny rule with logging enabled.
5. **Intentionally misconfigured static route (`nic-lab-broken-route`):**
   - Destination `192.168.50.0/24` with `next_hop_instance = nic-lab-vm` while `can_ip_forward = false`.
   - Triggers Network Analyzer's invalid next-hop insight (`ROUTE_NEXT_HOP_VM_IP_FORWARDING_DISABLED` under `google.networkanalyzer.vpcnetwork.connectivityInsight`).

---

## Prerequisites

- A disposable Google Cloud project with billing enabled.
- Terraform >= 1.5.0 and Google Cloud CLI (`gcloud`) installed and authenticated.
- Required IAM roles:
  - Firewall Insights: `roles/serviceusage.serviceUsageAdmin` (to enable APIs) and `roles/recommender.firewallAdmin` (or `roles/recommender.firewallViewer` for read-only viewing).
  - Network Analyzer: `compute.networks.list` and `compute.instances.list` for console viewing, plus Recommender viewer permissions (e.g., `recommender.networkAnalyzerConnectivityInsights.list`) for CLI/API queries.

---

## Step 1: Deploy the Lab with Terraform

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your disposable project_id

terraform init
terraform plan
terraform apply
```

---

## Step 2: Enable Firewall Insights Features

Enabling `firewallinsights.googleapis.com` and `recommender.googleapis.com` is the first step, and Firewall Insights does not generate shadowed or overly permissive rule insights until you explicitly enable them:

- **Console:** Go to **Network Intelligence Center > Firewall Insights > Configuration > Enablement** and toggle **Shadowed rule insights** and **Overly permissive rule insights** to **Enabled**.
- **Timing note (official docs):** After enabling shadowed or overly permissive rule insights, it can take up to **48 hours** for generated insights to appear, and up to **10 days** after creating/updating a rule for machine learning future-hit predictions.

---

## Step 3: Inspect Firewall Insights with `gcloud`

```bash
export PROJECT_ID="your-disposable-gcp-project-id"

# Verify APIs are enabled
gcloud services list --enabled --project="$PROJECT_ID" \
  --filter="name:(firewallinsights|recommender|logging|compute)"

# List Firewall Insights via Recommender CLI
gcloud recommender insights list \
  --project="$PROJECT_ID" \
  --location=global \
  --insight-type=google.compute.firewall.Insight \
  --format=json
```

---

## Step 4: Inspect Network Analyzer Findings with `gcloud`

Network Analyzer runs continuously and triggers analysis approximately **10 minutes** after a relevant configuration change (plus periodic analysis at least once daily).

```bash
# List VPC connectivity insights (includes invalid next-hop routes)
gcloud recommender insights list \
  --project="$PROJECT_ID" \
  --location=global \
  --insight-type=google.networkanalyzer.vpcnetwork.connectivityInsight \
  --format=json

# Describe a specific insight (replace INSIGHT_ID with the ID from the list output)
gcloud recommender insights describe INSIGHT_ID \
  --project="$PROJECT_ID" \
  --location=global \
  --insight-type=google.networkanalyzer.vpcnetwork.connectivityInsight
```

Look for `insightSubtype: "ROUTE_NEXT_HOP_VM_IP_FORWARDING_DISABLED"` pointing at `nic-lab-broken-route` and `nic-lab-vm`.

Optional remediation test: to fix the invalid next-hop finding without deleting the route, export the VM properties, set `canIpForward: true`, and update with `--most-disruptive-allowed-action=REFRESH` as documented in the official Network Analyzer invalid next-hop guide (or delete the unnecessary route).

---

## Step 5: Teardown and Cost Cleanup

Destroy all Terraform-managed resources as soon as you finish:

```bash
terraform destroy
```

### Post-Destroy Verification & Disable Unneeded Logging

1. **Disable Firewall Insights insight generation (optional if keeping the project):**
   - In **Network Intelligence Center > Firewall Insights > Configuration > Enablement**, toggle **Shadowed rule insights** and **Overly permissive rule insights** to **Disabled** (note: disabling deletes previously generated insights).
2. **Verify no leftover VMs, external IPs, or firewall rules with logging remain:**
   ```bash
   gcloud compute instances list --project="$PROJECT_ID"
   gcloud compute addresses list --project="$PROJECT_ID"
   gcloud compute firewall-rules list --project="$PROJECT_ID" \
     --filter="logConfig.enable=true"
   gcloud logging sinks list --project="$PROJECT_ID"
   ```
3. **Disable firewall logging on any remaining custom rules** if you are reusing the project:
   ```bash
   gcloud compute firewall-rules update RULE_NAME \
     --project="$PROJECT_ID" \
     --no-enable-logging
   ```
4. If you created a dedicated disposable project for this lab, you can delete the entire project when finished to guarantee zero ongoing charges.
