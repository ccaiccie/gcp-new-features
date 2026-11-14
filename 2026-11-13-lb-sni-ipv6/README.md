# SNI routing with TLS routes and IPv6 frontends

Terraform practice lab for this video: https://youtu.be/_lG3L0Ufflo

## Goals

- Create a regional external proxy Network Load Balancer with a target TCP proxy
- Attach a regional `google_network_services_tls_route` that selects a backend service from the TLS ClientHello SNI hostname
- Add both an IPv4 and an IPv6 frontend, with a dual-stack frontend subnet and an `IPV4_IPV6` proxy-only subnet

## Prerequisites

- A Google Cloud project and billing enabled
- `gcloud` authenticated (`gcloud auth application-default login`) and `terraform` 1.6+
- IAM that can create the resources in this folder (typically Project Editor, or narrower roles listed by the APIs you enable)
- Enable the APIs named in the steps below, or let Terraform enable them if you uncomment the `google_project_service` resources

## Cost warning

Forwarding rules and a regional proxy Network Load Balancer incur load-balancing charges while they exist, even if you attach no VM backends. IPv6 and IPv4 addresses can also incur address charges. This lab does not create VMs. Destroy the lab as soon as you have inspected the configuration.

## What this lab cannot provision

This lab does not create VM or NEG backends, so health checks stay unhealthy and there is no live TLS traffic to inspect. Distributed tracing with Cloud Trace (preview) and the `ALLOW_VALIDATION_RELAXATIONS` mTLS option from the video are not configured here; they apply to other load balancer types and are not required for SNI routing.

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

Enable the APIs if needed:

```bash
gcloud services enable compute.googleapis.com networkservices.googleapis.com --project YOUR_PROJECT_ID
```

## Verify

```bash
terraform output
gcloud network-services tls-routes describe "$(terraform output -raw tls_route)" --location us-east4 --project YOUR_PROJECT_ID
gcloud compute forwarding-rules list --regions us-east4 --project YOUR_PROJECT_ID
```

Confirm the TLS route lists both SNI hosts, that one forwarding rule has `ipVersion: IPV6`, and that the proxy-only subnet stack type is `IPV4_IPV6`.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the cloud console that the project, resource group, or VPC resources are gone.
