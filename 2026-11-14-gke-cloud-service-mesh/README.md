# Cloud Service Mesh on GKE

Terraform practice lab for this video: https://youtu.be/9rCOWzwU5PQ

## Goals

- Enable the fleet `servicemesh` feature
- Optionally create a GKE Autopilot cluster, register it as a fleet membership, and turn on managed Cloud Service Mesh (`mesh.management = MANAGEMENT_AUTOMATIC`)
- Leave a ready cluster you can use to practice mTLS, Gateway API HTTPRoutes, and traffic splits from the lesson

## Prerequisites

- A Google Cloud project and billing enabled
- `gcloud` authenticated (`gcloud auth application-default login`) and `terraform` 1.6+
- IAM that can create the resources in this folder

- You need permission to create GKE clusters and GKE Hub / Fleet resources

## Cost warning

A GKE Autopilot cluster has an hourly cost even with no user workloads, and managed Cloud Service Mesh adds control-plane and data-plane usage once workloads are injected. This is the most expensive lab in this set if you leave it running. Set `create_cluster = false` if you only want to enable the project-level mesh feature. Destroy the cluster as soon as you finish practicing.

## What this lab cannot provision

The Google provider can provision managed Cloud Service Mesh on a fleet membership. It does not expose arguments for ambient data plane (preview, allowlist), proxyless gRPC, ISTIOD versus TRAFFIC_DIRECTOR selection, Mesh CA versus CA Service, or Gateway API GAMMA routes. Those objects are Kubernetes or mesh configuration, not Terraform provider resources, and this lab does not invent them.

After the cluster is ready, follow the current Cloud Service Mesh documentation to deploy a sample, enable auto mTLS, and apply an HTTPRoute. Regional Cloud Service Mesh and GCPAuthzPolicy remain preview or limited features and are not declared here.

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
gcloud services enable container.googleapis.com gkehub.googleapis.com mesh.googleapis.com --project YOUR_PROJECT_ID
```

Get credentials after apply:

```bash
gcloud container clusters get-credentials csm-lab-cluster --region us-central1 --project YOUR_PROJECT_ID
```

## Verify

```bash
terraform output
gcloud container clusters describe csm-lab-cluster --region us-central1 --project YOUR_PROJECT_ID --format='value(status)'
gcloud container fleet mesh describe --project YOUR_PROJECT_ID
```

Confirm the membership shows managed mesh status (it can take several minutes after apply). Then, from the lesson, you can apply an HTTPRoute with a Service `parentRef` in the cluster; that step is Kubernetes YAML, not part of this Terraform.

## Cleanup

Destroy the lab when you are finished so you are not billed for idle resources:

```bash
terraform destroy
```

Confirm in the cloud console that the project, resource group, or VPC resources are gone.
