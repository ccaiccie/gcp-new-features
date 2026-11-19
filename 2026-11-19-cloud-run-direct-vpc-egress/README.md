# Cloud Run networking: Direct VPC egress versus Serverless VPC Access connectors

Terraform practice lab for the GCP New Features video "Cloud Run Networking: Direct VPC Egress vs Serverless VPC Access Connectors" (YouTube playlist **gcp new features**, Network Technician channel).

A Cloud Run service or job does not live in your VPC. This lab gives a Cloud Run job a path into a VPC with **Direct VPC egress** (one network interface per instance, addresses from your subnet), proves it can reach a private VM, and proves that with `egress = ALL_TRAFFIC` the internet sees your **Cloud NAT static address**. An optional switch also builds a **Serverless VPC Access connector** so you can compare both paths.

## What it builds

| Piece | Why it matters |
| --- | --- |
| VPC `dvpc-vpc`, subnet `10.10.0.0/26` with Private Google Access | Direct VPC egress needs a /26 or larger; about 2 IPs per instance, reserved in /28 blocks. Private Google Access keeps Google API calls working when all traffic enters the VPC |
| Backend VM `dvpc-backend` at `10.10.0.10`, no external IP, web page on port 80 | A private destination that Cloud Run cannot reach without a VPC path |
| Cloud Router + Cloud NAT with one reserved static IP (errors-only logging) | With `ALL_TRAFFIC`, internet-bound traffic from Cloud Run is translated to this one address |
| Ingress rule: TCP 80 to tag `backend` from `10.10.0.0/26` | Cloud Run IPs are ephemeral and Cloud Run tags cannot be an ingress *source*, so allow the subnet range |
| Egress rules for tag `run-egress`: deny all (priority 65000), allow TCP 80 to the backend, allow TCP 443 out | Network tags on the Cloud Run revision/execution let egress rules target exactly this workload |
| Cloud Run job `dvpc-probe` (`google_cloud_run_v2_job`) with `vpc_access.network_interfaces`, `egress = ALL_TRAFFIC`, tag `run-egress` | Fetches the backend page, then asks a public echo service which source address it sees |
| Optional (`create_connector = true`): connector `dvpc-conn` (`10.8.0.0/28`, e2-micro, 2 to 3 instances) and job `dvpc-probe-connector` | Same test through a connector: compare cost, source addresses and firewall identity |

## Prerequisites

- A Google Cloud project with billing enabled, and permission to enable APIs and create Compute Engine, Cloud Run and Serverless VPC Access resources (Owner or Editor in a lab project is simplest).
- Google Cloud CLI (`gcloud`) signed in: `gcloud auth login` and `gcloud auth application-default login`.
- Terraform 1.6 or later; provider `hashicorp/google` 8.11.0 (pinned in `versions.tf`).
- The lab enables `compute.googleapis.com`, `run.googleapis.com` and `vpcaccess.googleapis.com`. On a brand-new project, wait a minute after the first apply if an API was only just enabled, then apply again.
- The job image is `curlimages/curl` from Docker Hub; Cloud Run pulls it directly (image pulls do not use the VPC path).

## Cost warning

The e2-micro VM, the static IP, Cloud NAT and the job executions are billed (small amounts). The optional connector adds connector VMs that run all the time. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars     # set project_id (and region/zone if you like)
terraform init
terraform validate
terraform plan
terraform apply

# run the Direct VPC egress job and wait for it
$(terraform output -raw run_job_command)
```

Then read the job output in Cloud Logging (replace the region if you changed it):

```bash
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="dvpc-probe"' \
  --limit 20 --format 'value(textPayload)' --freshness 15m
terraform output nat_static_ip
```

## Expected results

- `== private backend via Direct VPC egress ==` followed by `hello from the private backend dvpc-backend at 10.10.0.10`.
- `== public source address seen by the internet ==` followed by **the same address as `terraform output nat_static_ip`**.
- `gcloud run jobs describe dvpc-probe --region us-central1` shows the network, subnet, network tag `run-egress` and egress `all-traffic`.
- `gcloud compute addresses list --filter="purpose=SERVERLESS"` (while or shortly after a job runs) lists addresses from `10.10.0.0/26` that Cloud Run reserved.

The VM's startup script takes about a minute after creation; if the first run prints `backend: FAILED`, wait a minute and execute the job again. New Direct VPC egress instances can also take some time to establish connections, which is why the job uses a 10 second curl timeout and you may simply re-run it.

## Verification checklist

1. Backend reachable through Direct VPC egress: the job prints the backend page.
2. Static egress: the echo address equals `nat_static_ip`.
3. Firewall by tag: in `main.tf`, change `run_allow_backend` priority to `65001` (below the deny-all), `terraform apply`, re-run the job: the backend call now fails while the echo call still works. Change it back.
4. Egress setting: set `vpc_egress = "PRIVATE_RANGES_ONLY"` in `terraform.tfvars`, apply, re-run: the backend still works, but the echo address is **no longer** your NAT IP, because internet traffic now leaves directly from Google's pool and never enters the VPC.

## Experiments

1. **Compare with a connector.** Set `create_connector = true`, apply, and run `gcloud run jobs execute dvpc-probe-connector --region us-central1 --wait`. Connector VMs are managed for you; Cloud Billing reports show their compute charges under the label `serverless-vpc-access`. Note that the backend firewall rule must allow the connector range `10.8.0.0/28`.
2. **Subnet sizing.** Try `run_subnet_cidr = "10.10.0.0/27"`: the variable validation refuses it, matching the /26 minimum for Direct VPC egress.
3. **Startup probe.** For a Cloud Run *service*, add a startup probe that calls an egress destination with retries, so instances only take traffic once their VPC networking works.

## Cleanup

```bash
terraform destroy
```

If destroy reports that the subnet is still in use, Cloud Run has not released its reserved addresses yet. Wait one to two hours after the last job execution and run `terraform destroy` again. The enabled APIs are left on (`disable_on_destroy = false`).

## References

- Direct VPC egress with a VPC network — https://cloud.google.com/run/docs/configuring/vpc-direct-vpc
- Compare Direct VPC egress and VPC connectors — https://cloud.google.com/run/docs/configuring/connecting-vpc
- Serverless VPC Access — https://cloud.google.com/vpc/docs/serverless-vpc-access
- Static outbound IP address for Cloud Run — https://cloud.google.com/run/docs/configuring/static-outbound-ip
- google_cloud_run_v2_job — https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job
