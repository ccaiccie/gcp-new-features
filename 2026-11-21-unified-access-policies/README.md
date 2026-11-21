# Unified Access Policies (UAP) in Cloud IAM (preview)

Practice lab for the **Unified Access Policies in Cloud IAM** lesson (Network Technician, GCP new features, November 21, 2026). Unified Access Policies were announced in Preview on November 20, 2026.

Video: [Unified Access Policies in Cloud IAM on YouTube](https://youtu.be/xP9zX0clulU)

A Unified Access Policy holds **allow and deny rules in one policy**, and is applied to resources through separate, reusable **policy bindings**. This lab builds one UAP in a test project that:

1. **Allows** a network-automation service account to view network configuration (`role:roles/compute.networkViewer`), granted only by the UAP.
2. **Denies** every service account in the project the `compute.googleapis.com/firewalls.*` permission group, **except** a break-glass service account (excluded principal), and keeps `firewalls.get` and `firewalls.list` available (excluded permissions).

Both service accounts also get `roles/compute.securityAdmin` through the classic project allow policy, so you can watch a UAP deny rule override an allow-policy grant.

> **Not the same as Access Context Manager.** Access Context Manager (lesson of November 18, 2026) defines *context* such as IP ranges, regions and device state, for VPC Service Controls perimeters and IAP. A UAP is the IAM authorization model itself: *who* may use *which permissions* on *which resources*.

## Terraform support

Everything in this lab uses real resources in `hashicorp/google` **8.12.0**:

| Resource | Purpose |
| --- | --- |
| `google_iam_project_access_policy` | The UAP (also available: `google_iam_folder_access_policy`, `google_iam_organization_access_policy`) |
| `google_iam_projects_policy_binding` with `policy_kind = "ACCESS"` | Applies the UAP (also: `google_iam_folders_policy_binding`, `google_iam_organizations_policy_binding`) |
| `google_service_account`, `google_service_account_iam_member`, `google_project_iam_member`, `google_compute_network` | Test identities, impersonation for the tester, classic allow grants, a VPC for test firewall rules |

Honest notes:

- In provider 8.12.0 the schema description for `operation.permissions` still says that only `eventarc.googleapis.com/messageBuses.publish` is supported. The current UAP documentation (Preview, November 2026) says rules accept permissions, predefined roles (allow rules only, written `role:roles/...`) and permission groups. The lab follows the documentation. If the API rejects a rule in your project, the error will say so; report it and fall back to `gcloud iam access-policies create` with the JSON in this README.
- The lab was checked with `terraform validate` only. It was not applied in a live project while it was being written.
- A project-level UAP can only be bound to its own project. To bind one policy to many folders or projects, create it in the organization (see "Organization example" below).

## Prerequisites

- A **test** project. The deny rule changes who can edit firewall rules in it.
- On that project: Access Policy Admin (`roles/iam.accessPolicyAdmin`), which includes `iam.accesspolicies.create` and `iam.accesspolicies.bind`, plus permission to create service accounts and grant roles (for example Project IAM Admin and Service Account Admin).
- The organization policy constraint `iam.managed.disableAccessPolicyBinding` must **not** be enforced, or binding creation fails.
- Terraform 1.6 or later and the Google Cloud CLI.
- If you run Terraform as a service account in the same project, that account is also covered by the deny rule (it is "every service account in the project"). Run the lab as a user account.
- Cost: no charge for UAPs. The lab creates no VMs; the test firewall rules are deleted by the test script.

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id and tester_member
terraform init
terraform apply
./scripts/inspect-uap.sh "$(terraform output -raw netops_sa | cut -d@ -f2 | cut -d. -f1)"
eval "$(terraform output -raw test_command)"
```

IAM changes are eventually consistent. If a test result looks wrong right after `apply`, wait a few minutes and run the test again.

Expected results:

| Test | Identity | Expected | Why |
| --- | --- | --- | --- |
| 1. list firewall rules | netops | allowed | UAP allow rule (networkViewer), and `firewalls.list` is excluded from the deny rule |
| 2. create firewall rule | netops | **denied** | UAP deny rule, even though the allow policy grants Compute Security Admin |
| 3. create firewall rule | break-glass | allowed | Excluded principal in the deny rule; allow policy grants the permission |
| 4. describe the rule | netops | allowed | `firewalls.get` is an excluded permission |
| 5. delete the rule | break-glass | allowed | Cleanup |

Policy Troubleshooter does **not** support UAPs. To investigate access, list the UAP bindings on the resource and its ancestors and read each bound policy (`scripts/inspect-uap.sh`).

## Organization example (not applied by this lab)

Create the policy once at the organization, then bind it to several folders or projects:

```bash
gcloud iam access-policies create network-guardrail \
  --organization=ORG_ID --location=global \
  --display-name="Network guardrail" --details-rules=rules.json

gcloud iam policy-bindings create guardrail-prod \
  --folder=PROD_FOLDER_ID --location=global \
  --policy="organizations/ORG_ID/locations/global/accessPolicies/network-guardrail" \
  --target-resource="//cloudresourcemanager.googleapis.com/folders/PROD_FOLDER_ID"
```

`rules.json` uses the same rule format as the Terraform `rules` blocks: `effect`, `principals`, `excludedPrincipals`, `operation.permissions`, `operation.excludedPermissions`, and optional `conditions`.

## Limits (as documented, Preview)

- Up to **100 rules** per UAP.
- The UAP documentation says one UAP can be bound to up to **5 resources**, and one resource can have up to **5** UAPs bound to it. Google's announcement blog says a policy can be bound to up to **25** organization, folder or project targets in Preview. Check the current documentation before you design around either number.
- The announcement blog gives 64 KB per UAP. The documentation pages used for this lab did not state a size limit.
- Roles are allowed only in allow rules. Custom roles are not supported in any rule. Deny rules accept only the permission groups listed as supported for deny policies.
- Conditions go on rules, not on bindings. You can't bind a UAP across organizations.

## Clean up

```bash
terraform destroy
```

Delete any test firewall rules that a failed test run left behind (`gcloud compute firewall-rules list --filter="name~^uap-test"`).

## Sources

- Announcement blog, November 20, 2026: https://cloud.google.com/blog/products/identity-security/how-to-simplify-cloud-access-with-unified-access-policies
- Unified Access Policies overview: https://docs.cloud.google.com/iam/docs/unified-access-policies
- Create and apply UAPs: https://docs.cloud.google.com/iam/docs/unified-access-policies-create-apply
- Principal identifiers for UAPs: https://docs.cloud.google.com/iam/docs/principal-identifiers
- Permissions supported in deny policies: https://docs.cloud.google.com/iam/docs/deny-permissions-support
- Troubleshoot IAM-related policies: https://docs.cloud.google.com/iam/docs/troubleshoot-policies
- Terraform: `google_iam_project_access_policy`, `google_iam_projects_policy_binding` in hashicorp/google 8.12.0
