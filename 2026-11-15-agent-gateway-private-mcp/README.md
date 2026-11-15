# Private MCP connectivity: Gemini Enterprise, Agent Gateway, and PSC

Practice lab for the [Private connectivity for Gemini Enterprise MCP servers](https://github.com/ccaiccie/gcp-new-features/tree/main/2026-11-15-agent-gateway-private-mcp) lesson.

This configuration builds the networking foundation, and the Agent Gateway pieces that Google provider 8.11.0 supports, for routing Gemini Enterprise tool calls to an internal Cloud Run service through an egress Agent Gateway, a Private Service Connect endpoint for Google APIs, and a private Cloud DNS zone in a Shared VPC.

## What Terraform creates

In the **host** project:

- A Shared VPC host and a custom-mode VPC.
- An attachment subnet with Private Google Access, which is the source range for gateway egress.
- A reserved global `/32` and a PSC forwarding rule targeting `all-apis`. The default address is `172.16.20.20`, the example used in the official walkthrough. Change it if it overlaps an existing range.
- A private Cloud DNS zone for `run.app.`, authorized for the Shared VPC, with a wildcard A record pointing at that `/32`.
- IAM on the host for the Agent Gateway service agent: Network User on the subnet, plus Network Viewer, DNS Reader, and DNS Peer on the project.
- A firewall rule allowing TCP 443 from the attachment subnet to the PSC `/32`.

In the **service** project (recommended topology):

- Shared VPC service-project attachment.
- A PSC network attachment that references the host subnet.
- A Cloud Run service with `INGRESS_TRAFFIC_INTERNAL_ONLY`. The default image is the Cloud Run hello container; it is a stand-in, not a StreamableHTTP MCP server.
- Cloud Run Invoker for the Gemini Enterprise / Discovery Engine service agent, which is the IAM half of dual-header auth on a default `.run.app` URL.
- An `AgentConnectivityTemplate` (`PRIVATE_RANGES_ONLY`, DNS peering for `run.app.`, target network is the host VPC).
- A Google-managed egress Agent Gateway (`AGENT_TO_ANYWHERE`) that references the template.

## What Terraform cannot do yet

Provider 8.11.0 does not create a Gemini Enterprise app, a custom MCP data connector, or the authorization policy that the gateway requires. Until you add a policy, egress through the gateway is denied with HTTP 403. Complete these steps after `terraform apply`, using the official documents linked at the end:

1. **Authorization policy.** Bind an authorization policy to the gateway's full resource path (`projects/SERVICE_PROJECT/locations/REGION/agentGateways/GATEWAY_NAME`). Start with a basic allow policy, or deploy an IAP authorization extension (optionally in `DRY_RUN`) and IAM policies if you are using Agent Registry. See [Create an authorization policy](https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-vpc-custom-mcp-server#create-an-authorization-policy).
2. **Replace the Cloud Run image** with your StreamableHTTP MCP server if you want a real connector. The older SSE transport is not supported.
3. **Gemini Enterprise app.** Bind the app to the egress gateway (`agentGatewaySetting`) and, on the custom MCP connector, turn on **Route egress through Agent Gateway** (`use_agent_gateway_egress`). Both settings are required. Supported regions for this path are `us-central1` and `europe-west1`.
4. **OAuth 2.0 (optional but part of dual-header auth).** Register Gemini Enterprise as an OAuth client with redirect URL `https://vertexaisearch.cloud.google.com/oauth-redirect`, then configure the client ID, secret, and scopes on the connector. The `Authorization` header keeps the user token. The Google-signed ID token is sent only in `X-Serverless-Authorization`, and only when the connector URL is the default `.run.app` URL.
5. **Organization policy.** Override the constraint that blocks Custom MCP data store creation, and allow the FQDNs you need, before creating the connector.

## Prerequisites

- Two Google Cloud projects in the **same organization**. One is the host, the other is the service project. A project cannot be both.
- Billing enabled on both projects.
- Permission to enable the APIs listed in `main.tf` in both projects.
- IAM on the organization or folder: Shared VPC Admin (`roles/compute.xpnAdmin`) and Project IAM Admin, or equivalent permissions to enable a host and attach a service project.
- Permission to create a VPC, subnet, PSC endpoint, Cloud DNS private zone, firewall, network attachment, Cloud Run service, Agent Connectivity Template, and Agent Gateway.
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.6 or later, and a Google Cloud credential that Terraform can use (`gcloud auth application-default login`, or a service account).

If your organization uses `constraints/compute.restrictSharedVpcHostProjects` or `constraints/compute.restrictSharedVpcSubnetworks`, make sure this host and subnet are allowed. Do not commit `terraform.tfvars` or state files (the repo `.gitignore` already excludes them).

## Steps

1. Copy the example variables and set your project IDs:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edit host_project_id and service_project_id
   # optionally change region (us-central1 or europe-west1) and psc_google_apis_ip
   ```

2. Initialize, review, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Terraform enables the required APIs (it does not disable them on destroy), then creates the Shared VPC, PSC endpoint, private DNS zone, network attachment, internal Cloud Run service, connectivity template, and egress Agent Gateway.

3. Confirm the service project is attached, and that the zone answers the Cloud Run hostname with the reserved `/32`:

   ```bash
   gcloud compute shared-vpc get-host-project SERVICE_PROJECT_ID
   terraform output psc_google_apis_ip
   terraform output cloud_run_uri
   ```

## Cleanup

```bash
terraform destroy
```

Destroy removes the gateway, template, Cloud Run service, attachment, DNS, PSC endpoint, IAM bindings, subnet, VPC, and the host/service attachment. While the project is still a Shared VPC host, Google Cloud places a lien on it so it cannot be deleted accidentally. That lien is removed when host status is disabled, which this destroy step does.

If destroy fails because a resource still uses the shared subnet, delete or disconnect that resource and run `terraform destroy` again. Cloud Run VPC egress reservations and PSC network attachments can take several minutes to release.

## Official documents

- [Set up Agent Gateway with VPC connectivity](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/gateways/set-up-vpc-connectivity)
- [Prerequisites to set up a custom MCP server data store with VPC connectivity](https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-vpc-custom-mcp-server)
- [Set up your custom MCP server data store](https://docs.cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-custom-mcp-server) (dual-header auth and Route egress through Agent Gateway)
- [Agent Gateway egress from Agent Runtime to VPC network](https://codelabs.developers.google.com/agw-cuj-arun-egress-vpc)
- [Governing agentic workloads with Agent Gateway](https://codelabs.developers.google.com/cloudnet-agent-gateway)
