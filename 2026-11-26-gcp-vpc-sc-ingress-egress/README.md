# VPC Service Controls Lab: Ingress & Egress Rules, Dry-Run Mode, and Violation Analyzer

> **SAFETY WARNING:** Use a **disposable test project and disposable test organization ONLY**. VPC Service Controls is an organization-level control. An enforced service perimeter can block access to Google Cloud services until it is removed. **Do not attach this lab to a production organization.**

## What You Will Practice
1. Create a regular **VPC Service Controls** service perimeter in **dry-run mode** protecting Cloud Storage (`storage.googleapis.com`) and BigQuery (`bigquery.googleapis.com`).
2. Observe dry-run violations in **Cloud Audit Logs** without breaking live access.
3. Add **ingress** and **egress** policies progressively in dry-run mode.
4. Promote the dry-run configuration to **enforced mode** (remembering that perimeter updates can take **up to 30 minutes** to propagate and may return `Error 403: Request is prohibited by organization's policy.` during that window).
5. Trigger a denied request with an identity not allowed by the ingress rule, capture the **unique ID** (or `vpcServiceControlsTroubleshootToken`), and diagnose it in the **VPC Service Controls violation analyzer** in the Google Cloud console.
6. Tear down the perimeter completely so no leftover enforced rules continue blocking your test project.

## Prerequisites
- A **disposable Google Cloud organization** with an Access Context Manager access policy (`access_policy_id`).
- Two disposable projects in that organization:
  - `protected_project_id` / `protected_project_number` (placed inside the perimeter)
  - `external_project_number` (outside the perimeter, used as the egress target)
- Organization-level IAM permissions to manage Access Context Manager perimeters (`roles/accesscontextmanager.policyAdmin`), plus:
  - For the Violation Analyzer comprehensive report: `roles/accesscontextmanager.policyReader` on the access policy and `roles/logging.viewer` on the protected project (and `roles/accesscontextmanager.editor` only if applying Preview remediation suggestions).
  - For the classic troubleshooting report: `roles/accesscontextmanager.vpcScTroubleshooterViewer` at the organization level.
- Terraform >= 1.5 and Google Cloud CLI (`gcloud`).

## Option A: Terraform Walkthrough

### 1. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your disposable test org policy ID, project numbers, and identity
```

### 2. Deploy in Dry-Run Mode First (`enforce_perimeter = false`)
```bash
terraform init
terraform plan
terraform apply
```
This sets `use_explicit_dry_run_spec = true` and populates only `spec {}` (dry-run), leaving `status {}` (enforced) unset.

### 3. Inspect Dry-Run Audit Logs
Run a Cloud Storage or BigQuery command against the protected project, then query Cloud Audit Logs:
```bash
gcloud logging read \
  'log_id("cloudaudit.googleapis.com/policy") AND severity="error" AND protoPayload.metadata.dryRun="true"' \
  --project="YOUR_DISPOSABLE_PROTECTED_PROJECT" \
  --limit=20
```

### 4. Flip to Enforced Mode
Once dry-run audit logs show no unexpected violations, set `enforce_perimeter = true` in `terraform.tfvars` and run:
```bash
terraform apply
```
Allow up to **30 minutes** for propagation.

### 5. Generate a Denied Request & Use the Violation Analyzer
Run a Cloud Storage list command using a second test identity not listed in `ingress_policies`:
```bash
gcloud storage ls gs://YOUR_DISPOSABLE_PROTECTED_PROJECT-vpcsc-lab-bucket
```
Copy the **unique ID** from the `gcloud` error (or the `vpcServiceControlsTroubleshootToken` from Logs Explorer), then open the Google Cloud console at the **organization scope**:
- **Security -> VPC Service Controls -> Violation analyzer**, paste the unique ID, and click **Continue**; or
- **Logging -> Logs Explorer**, locate the denial row, click **VPC Service Controls -> Troubleshoot denial**.

Review the **Restricted resources**, **Restricted services**, **Ingress**, **Egress**, and **VPC accessible services** sections (and optionally click **Switch to classic view**).

### 6. Teardown (Important!)
Remove the perimeter and test bucket immediately when finished so enforced rules do not remain active:
```bash
terraform destroy
```

## Option B: `gcloud` CLI Walkthrough
See [`gcloud-walkthrough.sh`](./gcloud-walkthrough.sh), [`ingress.yaml`](./ingress.yaml), and [`egress.yaml`](./egress.yaml).

To tear down a perimeter created with `gcloud`:
```bash
gcloud access-context-manager perimeters delete lab_vpc_sc_demo_perimeter --policy=YOUR_POLICY_ID
```

## Official Google Cloud Documentation
- Ingress and egress rules: https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules
- Manage dry-run configurations: https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations
- Dry run mode overview: https://cloud.google.com/vpc-service-controls/docs/dry-run-mode
- Create a service perimeter: https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters
- Troubleshoot common issues: https://cloud.google.com/vpc-service-controls/docs/troubleshooting
- Diagnose an access denial in violation analyzer: https://cloud.google.com/vpc-service-controls/docs/violation-analyzer
- Diagnose an access denial and view the classic report: https://cloud.google.com/vpc-service-controls/docs/troubleshooter
