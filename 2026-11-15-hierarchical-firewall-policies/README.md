# Hierarchical firewall policies (organization and folder)

Terraform practice lab for the Network Technician lesson on Google Cloud hierarchical firewall policies.

Video: (link added when the video is published)

## Goals

- Create a hierarchical firewall policy parented by a folder
- Add an ingress rule at priority 500 that allows SSH from the Identity-Aware Proxy range (35.235.240.0/20)
- Add an ingress rule at priority 1000 that denies SSH from 0.0.0.0/0, with logging on both rules
- Associate the policy with the same folder so every VPC under that folder inherits it

## Prerequisites

- A Google Cloud organization with a folder you can use for this lab
- `gcloud` authentication (`gcloud auth application-default login`) plus `terraform` 1.6+
- The Compute Security Admin role (`roles/compute.securityAdmin`), or equivalent permissions, on that folder
- Hierarchical policies cannot be attached to a project. This lab does not invent an organization or folder. Set `folder_id` in `terraform.tfvars`.

## Cost warning

Hierarchical firewall policies and their associations are not billed like virtual machines or Cloud NAT, but the rules take effect immediately on every VM under the folder. Use a non-production folder. The deny rule will block SSH from the internet to those VMs; IAP SSH still works because of the higher-priority allow. Destroy the association and the policy when you finish.

## Steps

1. Copy the example variables and set your folder ID:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize and review the plan. `terraform validate` does not need credentials or a real folder ID.

   ```bash
   terraform init
   terraform plan
   ```

3. Apply only if this is a folder you intend to protect with these rules:

   ```bash
   terraform apply
   ```

## Verify

```bash
terraform output
gcloud compute firewall-policies describe "$(terraform output -raw firewall_policy_name)" --folder "$FOLDER_ID"
gcloud compute firewall-policies associations list --folder "$FOLDER_ID"
```

Expect two user rules (allow IAP SSH at priority 500, deny internet SSH at priority 1000) plus the predefined go-to-next rules at the lowest priority. In a project under the folder, the effective firewall rules view on a VM interface should list the inherited hierarchical rules first.

## Cleanup

Remove the association and the policy when you are finished:

```bash
terraform destroy
```

Confirm with `gcloud compute firewall-policies associations list --folder "$FOLDER_ID"` that the lab association is gone.
