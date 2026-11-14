# Secure Web Proxy as an Agent Gateway

Terraform practice lab for this video: https://youtu.be/4lOzDCCX5J0

## Goals

- Deploy a regional Secure Web Proxy (`google_network_services_gateway` with `type = "SECURE_WEB_GATEWAY"`), a gateway security policy, and a sample allow rule
- Attach a `google_network_services_agent_gateway` in self-managed mode to that proxy, which is the pattern the lesson describes
- Generate a lab TLS certificate at apply time (the private key is not stored in Git)

## Prerequisites

- A Google Cloud project and billing enabled
- `gcloud` authenticated (`gcloud auth application-default login`) and `terraform` 1.6+
- IAM that can create the resources in this folder

- This feature is preview. Google documents access by request (Agent Governance Preview sign-up). On Cloud Run it was a gated preview in `europe-west1` and `us-central1`. Apply may fail until your project is allowlisted.

## Cost warning

Secure Web Proxy is a billed networking service (the gateway and processed traffic). This lab also creates Certificate Manager and VPC resources. There are no GKE clusters or Cloud Run services, so you are not paying for those compute platforms. Destroy the lab when you finish.

## What this lab cannot provision

The lesson covers policies on the agentGateway resource itself (Model Armor and IAP extension bindings, MCP method and tool authorization, TLS inspection bypass) and says policies on the underlying proxy are ignored for that path. The Google provider documents `google_network_services_agent_gateway` with `self_managed`, `google_managed`, registries, and connectivity templates. It does not expose Model Armor extension bindings or MCP authorization policy arguments, so this lab does not invent them.

TLS inspection with a private CA, Cloud Service Mesh ambient routing from GKE, and Direct VPC egress from Cloud Run are also out of scope here so the lab stays small.

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

Enable APIs if needed:

```bash
gcloud services enable compute.googleapis.com   networkservices.googleapis.com   networksecurity.googleapis.com   certificatemanager.googleapis.com   --project YOUR_PROJECT_ID
```

If apply fails on the Agent Gateway with a permission or preview error, confirm you have been added to the Agent Governance Preview, then retry. The Secure Web Proxy can still be used on its own.

## Verify

```bash
terraform output
gcloud network-services gateways describe swp-agent-lab-swp --location us-central1 --project YOUR_PROJECT_ID
gcloud network-services agent-gateways describe swp-agent-lab-agent-gw --location us-central1 --project YOUR_PROJECT_ID
```

Confirm the gateway type is `SECURE_WEB_GATEWAY` and that the Agent Gateway `self_managed.resource_uri` points at that gateway.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the cloud console that the project, resource group, or VPC resources are gone.
