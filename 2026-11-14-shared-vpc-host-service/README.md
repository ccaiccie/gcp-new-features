# Shared VPC: host project versus service project

Terraform practice lab for the Network Technician lesson **Shared VPC: Host Project versus Service Project**.

This lab builds a small Shared VPC in a host project, attaches a service project, shares one subnet (with GKE Pod and Service secondary ranges) using subnet-level `roles/compute.networkUser`, and creates a sample VM in the service project on that subnet.

## Goals

- Enable a host project and attach a service project.
- Create a custom-mode VPC and a subnet with GKE secondary ranges in the host.
- Grant subnet-level Network User to the service project's Google APIs and default Compute service accounts (and to any extra members you list).
- Create a firewall rule for IAP SSH and another for traffic inside the subnet.
- Launch a small VM in the service project whose NIC uses the shared subnet.

## Prerequisites

- Two Google Cloud projects in the **same organization**. One will be the host, the other the service project. A project cannot be both.
- Billing enabled on both projects.
- The Compute Engine API will be enabled by this configuration. You still need permission to enable APIs in both projects.
- IAM on the organization or folder: Shared VPC Admin (`roles/compute.xpnAdmin`) and Project IAM Admin (`roles/resourcemanager.projectIamAdmin`), or equivalent permissions to enable a host and attach a service project.
- Permission to create a VPC, subnet, and firewall in the host project, and to create a VM in the service project.
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.6 or later, and a Google Cloud credential that Terraform can use (`gcloud auth application-default login`, or a service account).

If your organization uses the `constraints/compute.restrictSharedVpcHostProjects` or `constraints/compute.restrictSharedVpcSubnetworks` organization policies, make sure this host and subnet are allowed.

## Steps

1. Copy the example variables file and fill in your project IDs:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Optional: add your user or group to `network_user_members` so you can place more resources on the subnet later.

2. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. When you are finished, destroy the lab (see Cleanup).

## Verify

Confirm the service project is attached to the host:

```bash
gcloud compute shared-vpc get-host-project SERVICE_PROJECT_ID
```

Confirm the VM was created in the service project and received an address from the shared subnet (`10.0.1.0/24` by default):

```bash
gcloud compute instances describe svc-vm-1   --project=SERVICE_PROJECT_ID   --zone=us-central1-a   --format='yaml(name,networkInterfaces[0].networkIP,networkInterfaces[0].subnetwork)'
```

Confirm subnet-level Network User bindings:

```bash
gcloud compute networks subnets get-iam-policy tier-1   --project=HOST_PROJECT_ID   --region=us-central1
```

The VM has no external IP. To SSH, grant IAP tunnel access and use:

```bash
gcloud compute ssh svc-vm-1   --project=SERVICE_PROJECT_ID   --zone=us-central1-a   --tunnel-through-iap
```

## Cleanup

```bash
terraform destroy
```

Destroy removes the VM, IAM bindings, firewall rules, subnet, VPC, and the host/service attachment. While the project is still a Shared VPC host, Google Cloud places a lien on it so it cannot be deleted accidentally. That lien is removed when host status is disabled, which this destroy step does.

If destroy fails because a resource still uses the shared subnet, delete or disconnect that resource and run `terraform destroy` again.
