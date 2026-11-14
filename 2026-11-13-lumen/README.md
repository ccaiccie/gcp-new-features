# Partner Interconnect attachment (Lumen last-mile lesson)

Terraform practice lab for this video: https://youtu.be/dBONUA8W_Kg

## Goals

- Build the Google-side resources you would use with a Partner Interconnect: a VPC, a Cloud Router, and a Partner VLAN attachment in `us-east4`
- Export the attachment pairing key, which is what you would hand to a supported interconnect partner
- Practice the same region the Lumen last-mile preview announcement called out

## Prerequisites

- A Google Cloud project and billing enabled
- `gcloud` authenticated (`gcloud auth application-default login`) and `terraform` 1.6+
- IAM that can create the resources in this folder (typically Project Editor, or narrower roles listed by the APIs you enable)
- Enable the APIs named in the steps below, or let Terraform enable them if you uncomment the `google_project_service` resources

## Cost warning

This lab is intentionally small. A Partner Interconnect VLAN attachment is usually billed only after the partner provisions the circuit and the attachment becomes active. The Cloud Router itself does not have a separate charge, but a completed interconnect and egress would. Destroy the attachment if you do not intend to complete an order with a partner.

Do not use this lab to place a paid Lumen circuit unless you have already agreed that cost with Lumen.

## What this lab cannot provision

Lumen's Partner Cross-Cloud Interconnect for last mile (preview, announced November 12, 2026) is a partner-delivered service. The Google provider has no resources or arguments for ordering a Lumen last-mile circuit, reserving 1–50 Gbps flat-rate tiers, enabling wire-speed MACsec, or calling Lumen's interconnect API.

`google_compute_interconnect_attachment` with `type = "PARTNER"` is the nearest real Google Cloud resource: it creates the VLAN attachment and pairing key you would give to a partner. Completing the circuit still requires a partner order outside Terraform. Dedicated Interconnect and Cross-Cloud Interconnect (`type = "DEDICATED"` or `"PARTNER"` against a specific interconnect) are also not a substitute for a Lumen last-mile order, so this lab does not invent those objects.

## Steps

1. Copy the example variables and edit them:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize and review the plan:

   ```bash
   terraform init
   terraform plan
   ```

3. Apply only after you have read the cost warning:

   ```bash
   terraform apply
   ```

Enable Compute Engine if it is not already on:

```bash
gcloud services enable compute.googleapis.com --project YOUR_PROJECT_ID
```

## Verify

```bash
terraform output
gcloud compute interconnects attachments describe $(terraform output -raw attachment_name)   --region us-east4 --project YOUR_PROJECT_ID
```

Confirm the attachment type is `PARTNER` and that a pairing key is present. The state stays `PENDING_PARTNER` (or similar) until a partner claims the key. That is expected for this lab.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the cloud console that the project, resource group, or VPC resources are gone.
