# Partner Cross-Cloud Interconnect for Microsoft Azure (preview)

Terraform practice lab for the GCP New Features video "Partner Cross-Cloud Interconnect for Azure" (YouTube playlist **gcp new features**, Network Technician channel). Partner Cross-Cloud Interconnect for Microsoft Azure entered public preview on November 16, 2026.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Custom-mode VPC `pcci-az-vpc` and one subnet in the transport region | The Google Cloud side of the connection. Keep its range clear of the Azure VNet range |
| Firewall rule allowing ICMP and SSH from `azure_vnet_cidr` | Lets you ping and SSH across the interconnect once it is up |
| `google_network_connectivity_hub` (only when `connection_mode = "ncc"`) | NCC is one of the two ways to attach the transport. Mesh topology by default |
| `google_network_connectivity_transport` (only when `create_transport = true`) | The managed cross-cloud connection: region, Azure remote profile, Azure account ID and bandwidth. No ports, LOA-CFAs, VLAN attachments or BGP sessions to configure |

Paired locations (Azure preview):

| Google Cloud region | Azure region |
| --- | --- |
| us-east4 | eastus (Washington D.C.) |
| us-west2 | westus (Silicon Valley) |
| europe-west3 | germanywestcentral (Frankfurt) |

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0, and the IAM role `roles/networkconnectivity.transportAdmin` (plus `hubAdmin` or `groupAdmin` for the NCC option). To finish the connection you also need an Azure account and a VNet whose address space does not overlap `subnet_cidr`. The lab enables the Compute and Network Connectivity APIs.

## Cost warning

The VPC, subnet, firewall rule and hub are free. The transport is billed at a flat rate by bandwidth; the Google Cloud docs say that during the Azure preview "only 1 Gbps is available free of charge". Azure bills its side separately. Default quota is one transport per region per project. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # project, region, ranges
terraform init
terraform validate
terraform apply                                 # VPC side only (create_transport = false)

# Find the Azure remote profile for your region
gcloud network-connectivity transports remote-profiles list --region us-east4

# Put the profile name and your Azure account ID in terraform.tfvars, set create_transport = true
terraform apply
terraform output -raw pairing_key               # enter this key on the Azure side
terraform output transport_state
```

Complete the connection on the Azure side with the pairing key (Microsoft calls the service Azure Multicloud Interconnect). Then verify:

```bash
gcloud network-connectivity transports describe pcci-az-transport --region us-east4
gcloud compute routes list --filter="network~pcci-az"          # peering mode
gcloud network-connectivity hubs list-spokes pcci-az-hub        # NCC mode
gcloud network-connectivity hubs route-tables routes list --hub=pcci-az-hub --route_table=default
```

Route exchange between the two clouds is automatic. In peering mode, the transport creates a peering network to your VPC (`peering_network` output).

## Experiments

1. Switch `connection_mode` to `"ncc"` and compare the spokes and the hub route table with the peering mode routes.
2. Add a prefix to `advertised_routes` and check that Azure learns it.
3. Watch transport traffic in Cloud Monitoring while you ping a VM in Azure from a VM in the lab subnet.
4. Compare with the old way: read "Connect to Azure" under Cross-Cloud Interconnect (two ports, VLAN attachments, Cloud Router BGP, an ExpressRoute circuit) and list everything you did not have to configure here.

## References

- Google Cloud blog, Nov 17 2026 — https://cloud.google.com/blog/products/networking/cross-cloud-interconnect-for-microsoft-azure
- Release notes, Nov 16 2026 — https://docs.cloud.google.com/release-notes#November_16_2026
- Partner Cross-Cloud Interconnect for managed cloud partners — https://docs.cloud.google.com/network-connectivity/docs/interconnect/concepts/partner-cci-for-csp-overview
- Paired locations — https://docs.cloud.google.com/network-connectivity/docs/interconnect/how-to/partner-cci-for-csp/paired-locations
- Create a connection initiated from Google Cloud using NCC — https://docs.cloud.google.com/network-connectivity/docs/interconnect/how-to/partner-cci-for-csp/create-ncc-connectivity-gcp-to-csp
- google_network_connectivity_transport — https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_transport
- Microsoft, Connecting clouds and the last mile with Azure — https://techcommunity.microsoft.com/blog/azurenetworkingblog/connecting-clouds-and-the-last-mile-with-azure/4573283
