# Access Context Manager: access levels for IAP and VPC Service Controls

Terraform practice lab for the GCP New Features video "Access Context Manager for Network Technicians" (YouTube playlist **gcp new features**, Network Technician channel).

Access Context Manager **defines** request context (source IP ranges, countries, principals, device posture). It does not enforce anything by itself: VPC Service Controls, Identity-Aware Proxy, Context-Aware Access for Workspace and IAM conditions consume the access levels.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Scoped access policy for the lab project (`scopes = ["projects/NUMBER"]`) | Leaves your organization-level policy untouched. Skip it with `existing_access_policy_id` |
| Basic level `corp_network`: `ip_subnetworks` | Office egress CIDRs (IPv4/IPv6); several CIDRs are ORed |
| Basic level `allowed_regions`: `regions` | ISO 3166-1 alpha-2 codes, from the geolocation of the **public** source IP |
| Basic level `corp_and_region`: `required_access_levels` | Nesting: both levels must be granted |
| Custom level `office_hours` (CEL) | `inIpRange(origin.ip, ...) && origin.region_code in [...] && request.time.getHours(...)` |
| Optional basic level `managed_device` (`enable_device_level = true`) | Screen lock, encryption, corp-owned; needs Endpoint Verification and a paid subscription to be met |
| Cloud Storage bucket (`create_test_bucket`) | Something inside the perimeter |
| Service perimeter, **dry-run only** (`use_explicit_dry_run_spec = true`, `spec {}`, no `status {}`) | Restricts `storage.googleapis.com` in dry run, with an ingress rule whose source is `corp_and_region`. Nothing is enforced |

## Prerequisites and honest limits

- **An organization is required.** Access policies belong to an organization (`parent = organizations/ORG_ID`). A standalone project without an organization cannot run this lab.
- **Permissions at the organization:** Access Context Manager Admin or Editor (`roles/accesscontextmanager.policyAdmin` / `policyEditor`) to create the scoped policy, levels and perimeter. Creating scoped policies needs those permissions at the organization level. For console use you also need Organization Viewer.
- **One organization-level policy per organization.** This lab creates a *scoped* policy instead. If your project is already the scope of another scoped policy, or you want to use the org policy, set `existing_access_policy_id`; the lab then adds its levels and perimeter to that policy (be careful in a shared policy).
- **IAP cannot use scoped policies.** The `iap_condition_example` output only works if the levels live in the organization-level policy. The lab does not create an IAP binding.
- **Region checks only work for public source IPs.** Requests from private IPs or through Private Google Access never match a region condition.
- **Device attributes** (basic `device_policy` or `device.*` in CEL) need Endpoint Verification or MDM plus a paid enterprise security subscription. The optional level can be created without them but will not be met.
- **Principals** in access levels can be users or service accounts, not groups (ingress rules accept groups).
- Uses the user ADC quota project workaround from the provider docs (`billing_project` + `user_project_override = true`); you need `serviceusage.services.use` on the lab project and the Access Context Manager API enabled.
- Validated with `terraform validate` (Terraform 1.10, `hashicorp/google` 8.11.0). It was **not** applied against a real organization while recording the video.

## Cost

Access Context Manager and VPC Service Controls have no separate charge. The test bucket is empty and costs effectively nothing. **Run `terraform destroy` when you finish.**

## Steps

```bash
gcloud auth application-default login
gcloud services enable accesscontextmanager.googleapis.com --project YOUR_PROJECT
cp terraform.tfvars.example terraform.tfvars   # set project_id, org_id, corp_cidrs
terraform init
terraform plan
terraform apply
terraform output
gcloud access-context-manager levels list --policy $(terraform output -raw access_policy | cut -d/ -f2)
gcloud access-context-manager perimeters dry-run describe acm_lab_perimeter --policy $(terraform output -raw access_policy | cut -d/ -f2)
```

Then call the bucket from a network that is **not** in `corp_cidrs` (for example `gcloud storage ls gs://BUCKET` from Cloud Shell) and look in Logs Explorer for VPC Service Controls audit entries with `dryRun: true`. Repeat from your office range and compare.

## Experiments

1. Put `corp_cidrs` and `regions` in one condition, then split them into two conditions with `combining_function = "OR"`, and compare which requests are granted.
2. Set a CIDR with host bits (`192.0.2.1/24`) and read the API error.
3. Change the ingress rule source to the custom `office_hours` level and test outside business hours.
4. Add `ingress_identities = ["user:you@example.com"]` and compare with `ANY_IDENTITY`.
5. Only if you are ready to enforce: copy the `spec` into a `status {}` block in a sandbox project and watch real denials.

## Sources

- https://cloud.google.com/access-context-manager/docs/overview
- https://cloud.google.com/access-context-manager/docs/access-level-attributes
- https://cloud.google.com/access-context-manager/docs/custom-access-level-spec
- https://cloud.google.com/access-context-manager/docs/create-access-policy
- https://cloud.google.com/access-context-manager/docs/scoped-policies
- https://cloud.google.com/access-context-manager/docs/access-control
- https://cloud.google.com/vpc-service-controls/docs/use-access-levels
- https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules
- https://cloud.google.com/iap/docs/cloud-iap-context-aware-access-howto
- https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/access_context_manager_service_perimeter
