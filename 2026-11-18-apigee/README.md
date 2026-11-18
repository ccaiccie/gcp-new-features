# Apigee API management for network technicians

Terraform practice lab for the GCP New Features video "Apigee API management for network technicians" (YouTube playlist **gcp new features**, Network Technician channel). The lab provisions an Apigee **evaluation** organization and the networking around it, so you can see northbound and southbound traffic, VPC peering versus Private Service Connect (PSC), and environment groups in a real project.

## What it builds

| Piece | Why it matters |
| --- | --- |
| APIs: `apigee`, `compute`, `servicenetworking` | The APIs the Apigee provisioning steps enable |
| Custom-mode VPC `apigee-lab-vpc` and one subnet | Your side of the network; hosts the PSC NEG |
| `google_compute_global_address` + `google_service_networking_connection` (only when `networking_mode = "peering"`) | Reserves the range Apigee takes its /22 from and peers your VPC with the Apigee network (private service access) |
| `google_apigee_organization` (`billing_type = "EVALUATION"`) | The org. `disable_vpc_peering = true` in PSC mode; `authorized_network` in peering mode |
| `google_apigee_instance` | The runtime data plane in one region. Publishes a `service_attachment` for northbound PSC |
| `google_apigee_environment` x2 (`dev`, `prod`) + `google_apigee_instance_attachment` | Deployment targets, attached to the instance |
| `google_apigee_envgroup` + `google_apigee_envgroup_attachment` | The hostname lives on the group; both environments join it |
| Global external Application Load Balancer (`EXTERNAL_MANAGED`) with a PSC NEG (`create_northbound_lb = true`) | Northbound: client -> ALB -> PSC NEG -> instance service attachment. Google-managed certificate for `<lb-ip>.nip.io` (testing only) or your own `hostname` |
| `google_apigee_endpoint_attachment` (only when `backend_service_attachment` is set) | Southbound: Apigee -> endpoint attachment -> your PSC service attachment -> internal LB -> backend. Output `endpoint_attachment_host` is the address to use in a proxy TargetEndpoint |

## Read this first: limits, time and cost

- **Eval org lifespan.** An evaluation org lasts 60 days. Google sends a warning at day 30 and deletes the org at day 60. It cannot be extended or converted to a paid org.
- **Eval org size.** One instance (region), two environments, no SLA. Not for production, sensitive data, or performance/load testing. CMEK is not available on eval orgs.
- **One org per project.** The org takes the project ID as its name. If the project already has a paid Apigee org, you cannot create an eval org in it. Use a fresh lab project.
- **Provisioning time.** Google's docs say eval org provisioning can take up to 40-45 minutes, and creating or deleting an instance is a long-running operation of up to 20 minutes. The lab sets 60-minute create timeouts. Plan for a slow first `apply` and a slow `destroy`.
- **Networking choice is sticky.** `disable_vpc_peering` and `authorized_network` can only be changed while the org has no runtime instances. To switch `networking_mode`, destroy and re-create.
- **Peering mode ranges.** Each instance needs a non-overlapping /22 (eval) or /22 + /28 (paid) that nothing else in the VPC uses. Apigee peers with only one network.
- **Cost.** The eval org itself is not charged, but you need a billing account: the external load balancer, its forwarding rule, and Private Service Connect usage are billed under normal Compute Engine and VPC pricing, as are any test VMs. Set a budget alert. **Run `terraform destroy` when you finish.**
- **Managed certificate.** The Google-managed certificate only becomes `ACTIVE` after DNS for the hostname points at the load balancer IP. With the default `nip.io` name that is automatic, but it can still take a while.
- **Not in this lab.** Terraform does not deploy an API proxy bundle here. Deploy a test proxy from the Apigee UI (or `apigeecli`) with base path `/hello` to the `dev` or `prod` environment, then call `test_url`. The southbound producer (internal LB, PSC NAT subnet and service attachment) is also not built; bring your own and pass its ID.

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0, and the Apigee Organization Admin role (`roles/apigee.admin`) plus Compute Network Admin and Service Networking Admin (peering mode) on the project.

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # project, region, networking_mode
terraform init
terraform validate
terraform apply                                 # long: org + instance can take 45+ minutes

terraform output instance_service_attachment    # what the PSC NEG connects to
terraform output envgroup_hostname
terraform output test_url
```

Check what was built:

```bash
gcloud apigee organizations describe "$(gcloud config get-value project)"
gcloud apigee environments list
gcloud compute network-endpoint-groups list --filter="networkEndpointType=PRIVATE_SERVICE_CONNECT"
gcloud compute ssl-certificates list            # wait for ACTIVE
```

Deploy a test proxy with base path `/hello` to `prod`, then:

```bash
curl -i "$(terraform output -raw test_url)"
```

## Southbound with PSC (optional)

Publish a backend in your VPC behind an internal load balancer with a service attachment (and a subnet with `purpose = PRIVATE_SERVICE_CONNECT` for its NAT). Allow the Apigee project on the attachment's accept list (or accept automatically). Then:

```bash
terraform apply -var 'backend_service_attachment=projects/PROJECT/regions/REGION/serviceAttachments/NAME'
terraform output endpoint_attachment_host       # put this in the TargetEndpoint URL
terraform output endpoint_attachment_state      # want ACCEPTED
```

`PENDING` usually means the Apigee project is not on the service attachment's accept list; `REJECTED` means it is on the reject list; `CLOSED` means the service attachment was deleted. Only one endpoint attachment is allowed per service attachment in an org.

## Experiments

1. Run once with `networking_mode = "psc"`, destroy, then run with `"peering"`. Compare `gcloud compute networks peerings list --network apigee-lab-vpc` and the instance `host` output.
2. Add a second hostname to the environment group and call the proxy with `curl -H "Host: ..."`. Then move `prod` into its own group and see which hostname reaches which environment.
3. Attach an AccessControl policy that denies your own IP. Try `ValidateBasedOn` set to `X_FORWARDED_FOR_FIRST_IP` and `X_FORWARDED_FOR_LAST_IP` and note which address each one evaluates behind the load balancer.
4. Watch the PSC NEG and backend service in Cloud Monitoring while you send traffic.

## References

- What is Apigee? — https://docs.cloud.google.com/apigee/docs/api-platform/get-started/what-apigee
- Apigee networking options — https://docs.cloud.google.com/apigee/docs/api-platform/get-started/networking-options
- Apigee architecture overview — https://docs.cloud.google.com/apigee/docs/api-platform/architecture/overview
- Northbound networking with Private Service Connect — https://docs.cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc
- Southbound networking patterns — https://docs.cloud.google.com/apigee/docs/api-platform/architecture/southbound-networking-patterns-endpoints
- About environments and environment groups — https://docs.cloud.google.com/apigee/docs/api-platform/fundamentals/environments-overview
- Compare evaluation and paid organizations — https://docs.cloud.google.com/apigee/docs/api-platform/get-started/compare-paid-eval
- Provision an eval org (wizard) — https://docs.cloud.google.com/apigee/docs/api-platform/get-started/eval-orgs
- AccessControl policy — https://docs.cloud.google.com/apigee/docs/api-platform/reference/policies/access-control-policy
- Terraform provider: google_apigee_organization, google_apigee_instance, google_apigee_environment, google_apigee_envgroup, google_apigee_envgroup_attachment, google_apigee_instance_attachment, google_apigee_endpoint_attachment — https://registry.terraform.io/providers/hashicorp/google/latest/docs
