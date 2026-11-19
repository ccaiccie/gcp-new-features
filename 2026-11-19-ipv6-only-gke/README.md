# Single-stack IPv6 on GKE for AI/ML workloads (Preview)

Terraform practice lab for the GCP New Features video "Single-stack IPv6 on GKE for AI/ML workloads" (YouTube playlist **gcp new features**, Network Technician channel).

Single-stack IPv6 (Preview, announced November 18, 2026) runs GKE **nodes and Pods on IPv6 only, with no private IPv4**. Each node gets a `/112` Pod range (65,536 addresses) while the normal maximum-Pods-per-node limits still apply. Pods reach IPv4-only endpoints through **DNS64** (Cloud DNS synthesizes `64:ff9b::/96` AAAA answers) and **NAT64** on a regional Cloud NAT gateway. This lab builds that network with Terraform, creates the cluster with `gcloud`, and proves each piece from inside a Pod.

## Provider limitations (read first)

Checked against the `hashicorp/google` and `hashicorp/google-beta` provider schemas, version **8.12.0** (latest on November 19, 2026), with `terraform validate`:

| Piece | Terraform support | What this lab does |
| --- | --- | --- |
| VPC with internal ULA IPv6 | `google_compute_network.enable_ula_internal_ipv6` | Terraform |
| IPv6-only subnets (`INTERNAL` / ULA) | `google_compute_subnetwork.stack_type = "IPV6_ONLY"`, `ipv6_access_type = "INTERNAL"` | Terraform |
| DNS64 server policy | `google_dns_policy.dns64_config.scope.all_queries` | Terraform |
| Cloud NAT with NAT64 | `google_compute_router_nat.source_subnetwork_ip_ranges_to_nat64` + `nat64_subnetwork` | Terraform |
| **Single-stack IPv6 GKE cluster** | **Not supported.** `google_container_cluster.ip_allocation_policy.stack_type` accepts only `IPV4` or `IPV4_IPV6` in both providers (validate fails with `IPV6`). | `gcloud container clusters create ... --stack-type=ipv6`, run by a `terraform_data` resource with `local-exec` (set `create_cluster = false` to run it yourself) |
| GKE Granular NAT (Preview) | Configured with Kubernetes custom resources (`CloudNATGateway`, `TrafficSelector`), not a Terraform resource | Not part of this lab; see the lesson |

Two more honest notes:

- `google_compute_router_nat` requires `source_subnetwork_ip_ranges_to_nat` (the IPv4/NAT44 setting) even when you only want NAT64. This VPC has no IPv4 subnets, so the lab uses `LIST_OF_SUBNETWORKS` with no subnetwork blocks. If the API rejects that in your project, set `nat44_option = "ALL_SUBNETWORKS_ALL_IP_RANGES"` (still translates nothing, because there are no IPv4 ranges), or create the gateway with the gcloud command below.
- Because the cluster is created by `gcloud`, Terraform does not track its settings. `terraform destroy` deletes it with `gcloud container clusters delete` before it removes the network.

## What it builds

| Piece | Why it matters |
| --- | --- |
| VPC `v6gke-vpc`, custom mode, ULA internal IPv6 enabled (a `/48` from `fd20::/20`) | Required for single-stack IPv6 clusters, even if nodes use EXTERNAL addresses, because the PSC control plane subnet is INTERNAL |
| Subnet `v6gke-nodes`: `IPV6_ONLY`, `INTERNAL`, Private Google Access | The node subnet's `/64`; GKE gives each node a `/96` and a `/112` Pod range from it |
| Subnet `v6gke-psc-cp`: `IPV6_ONLY`, `INTERNAL` | `--private-endpoint-subnetwork`: nodes and Pods reach the control plane over Private Service Connect |
| DNS server policy `v6gke-dns64` with DNS64 for all queries (query logging on) | A name with only an A record gets a synthesized AAAA answer in `64:ff9b::/96` |
| Cloud Router `v6gke-router` + Cloud NAT `v6gke-nat64` with NAT64 for the node subnet, one static IPv4 address, logging | Translates `64:ff9b::/96` destinations to the embedded IPv4 address, with your static IPv4 as the source |
| Firewall `v6gke-allow-internal-v6` | Allows IPv6 from the VPC's own ULA `/48` (GKE also creates its own cluster rules) |
| Cluster `v6gke-cluster` (gcloud): GKE 1.37.1-gke.3020000+, Dataplane V2, Cloud DNS, `--stack-type=ipv6`, one `e2-standard-2` node | The Preview feature itself |

## Prerequisites

- A Google Cloud project with billing enabled, and permission to create Compute Engine, Cloud DNS and GKE resources (Owner or Editor in a lab project is simplest).
- Google Cloud CLI (`gcloud`) up to date (`gcloud components update`), signed in with `gcloud auth login` and `gcloud auth application-default login`, plus `kubectl` (`gcloud components install kubectl`). Terraform calls `gcloud`, so it must be on your PATH.
- Terraform 1.6 or later; provider `hashicorp/google` 8.12.0 (pinned in `versions.tf`).
- GKE version **1.37.1-gke.3020000 or later** available in your location. Check with:
  `gcloud container get-server-config --location=us-central1-a --format="yaml(validMasterVersions)" | grep 1.37`
- Preview machine families: E2, N1, N2, N2D, N4, C3, C3D, C4, C4D, C4A (Axion) and Z3, plus Cloud TPU v6e (Trillium).

## Cost warning

The GKE cluster management fee, the node VM, the static IP, Cloud NAT and NAT logs are billed. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars     # set project_id (and locations if you like)
terraform init
terraform validate
terraform plan
terraform apply                                  # network first, then the gcloud cluster create (about 10 minutes)

$(terraform output -raw get_credentials_command)
kubectl get nodes -o wide
```

If you set `create_cluster = false`, run `$(terraform output -raw cluster_create_command)` after the apply.

## Tests

### 1. Everything is IPv6

```bash
gcloud container clusters list --format="table(name,location,currentMasterVersion,ipAllocationPolicy.stackType)"
kubectl get nodes -o custom-columns=NAME:.metadata.name,INTERNAL_IP:.status.addresses[0].address,POD_CIDRS:.spec.podCIDRs
kubectl run netshoot --image=nicolaka/netshoot --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/netshoot --timeout=180s
kubectl get pod netshoot -o wide
```

Expected: stack type `IPV6`; node addresses from your `fd20:` ULA `/64` (`terraform output node_subnet_ipv6_range`); each node's Pod CIDR is a `/112`; the Pod address is IPv6. The `netshoot` image comes from Docker Hub, which this lab reaches through DNS64 and NAT64, so a successful pull is already a first NAT64 test.

### 2. DNS64: a synthesized AAAA record

```bash
kubectl exec netshoot -- dig +short A ipv4.icanhazip.com
kubectl exec netshoot -- dig +short AAAA ipv4.icanhazip.com
```

Expected: the A query returns IPv4 addresses; the AAAA query returns the same addresses embedded in `64:ff9b::/96` (for example `104.16.184.241` would come back as `64:ff9b::6810:b8f1`). The name has no real AAAA record, so Cloud DNS synthesized one.

### 3. NAT64: what the IPv4 internet sees

```bash
kubectl exec netshoot -- curl -s https://ipv4.icanhazip.com
terraform output nat64_external_ip
```

Expected: the two addresses match. The Pod has no IPv4 address at all; Cloud NAT translated the IPv6 source to your static IPv4 address and extracted the destination from the last 32 bits of the synthesized address.

### 4. Google APIs over IPv6, no NAT needed

```bash
kubectl exec netshoot -- curl -s -o /dev/null -w "%{http_code} %{remote_ip}\n" https://storage.googleapis.com
```

Expected: an HTTP status code and an IPv6 remote address (not `64:ff9b::`): Google APIs are reached over native IPv6 with Private Google Access.

### 5. Read the logs

```bash
gcloud logging read 'resource.type="nat_gateway"' --limit 5 --freshness 15m --format json
gcloud logging read 'resource.type="dns_query"' --limit 5 --freshness 15m --format json
```

## Experiments

1. **IPv4 firewall rules do not cover NAT64 by themselves.** Add an egress deny for the IPv4 address that `ipv4.icanhazip.com` resolves to, for example `gcloud compute firewall-rules create v6gke-deny-v4 --network=v6gke-vpc --direction=EGRESS --action=DENY --rules=all --destination-ranges=IPV4_ADDRESS/32 --priority=900`. Retry test 3: Pods still connect, because their packets carry the IPv6 destination. Add the IPv4-embedded IPv6 form as well (`64:ff9b::HEX:HEX/128`, from the dig output) and retry: now it is blocked. Delete both rules afterwards.
2. **Turn DNS64 off.** `gcloud dns policies update v6gke-dns64 --no-enable-dns64-all-queries`, wait a minute, and repeat tests 2 and 3: the AAAA query is empty and the IPv4-only site is unreachable. Run `terraform apply` to restore it.
3. **Metadata server.** `kubectl exec netshoot -- curl -s -m 3 http://169.254.169.254` fails in an IPv6-only Pod; `kubectl exec netshoot -- curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id` works. Old client libraries that hard-code the IPv4 address need `GCE_METADATA_HOST=metadata.google.internal`.
4. **Axion node pool (optional, extra cost).** `$(terraform output -raw axion_node_pool_command)`, then `kubectl get nodes -L kubernetes.io/arch`.

## The same network with gcloud

```bash
gcloud compute networks create v6gke-vpc --subnet-mode=custom --enable-ula-internal-ipv6
gcloud compute networks subnets create v6gke-psc-cp --network=v6gke-vpc --region=us-central1 --stack-type=ipv6_only --ipv6-access-type=INTERNAL
gcloud compute networks subnets create v6gke-nodes --network=v6gke-vpc --region=us-central1 --stack-type=ipv6_only --ipv6-access-type=INTERNAL --enable-private-ip-google-access
gcloud dns policies create v6gke-dns64 --description="DNS64 for single-stack IPv6 GKE" --networks=v6gke-vpc --enable-dns64-all-queries
gcloud compute routers create v6gke-router --network=v6gke-vpc --region=us-central1
gcloud compute routers nats create v6gke-nat64 --router=v6gke-router --region=us-central1 --auto-allocate-nat-external-ips --nat64-all-v6-subnet-ip-ranges
gcloud container clusters create v6gke-cluster --location=us-central1-a --cluster-version=1.37.1-gke.3020000 \
  --enable-dataplane-v2 --cluster-dns=clouddns --stack-type=ipv6 --network=v6gke-vpc \
  --subnetwork=v6gke-nodes --private-endpoint-subnetwork=v6gke-psc-cp --machine-type=e2-standard-2 --num-nodes=1
```

## Things the lab does not cover

- Single-stack IPv6 clusters do not support GKE Ingress (use Gateway API), Cloud Service Mesh, `kube-dns`, multi-subnet clusters, or the `--enable-private-nodes` and `--private-ipv6-google-access-type` flags. Existing IPv4 or dual-stack clusters cannot be converted in place; use a blue-green migration.
- Nodes and Pods on `INTERNAL` (ULA) subnets cannot reach public IPv6 sites outside Google: ULA is not routable on the internet and Cloud NAT has no NAT66. Use an `EXTERNAL` node subnet for that.
- GKE Granular NAT (Preview, November 18, 2026; GKE 1.37.1-gke.2611000+ with Dataplane V2) gives per-namespace egress addresses through `CloudNATGateway` and `TrafficSelector` resources. Its documentation describes IPv4 link-local SNAT (`169.254.32.0/20`) and does not say it applies to single-stack IPv6 clusters, so it is not combined with this lab.

## Cleanup

```bash
kubectl delete pod netshoot --ignore-not-found
terraform destroy
```

If you created the cluster yourself (`create_cluster = false`), delete it first: `gcloud container clusters delete v6gke-cluster --location=us-central1-a`.

## Sources

- Google Cloud blog, November 18, 2026: [Scaling massive AI/ML workloads with IPv6 on Google Kubernetes Engine clusters](https://cloud.google.com/blog/products/networking/run-aiml-workloads-on-ipv6-only-gke-clusters)
- GKE docs: [Create and manage single-stack IPv6 clusters](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/single-stack-ipv6)
- Cloud DNS docs: [Configure DNS64](https://docs.cloud.google.com/dns/docs/configure-dns64)
- VPC docs: [DNS64 and NAT64 for 6to4 connectivity](https://docs.cloud.google.com/vpc/docs/ipv6-to-ipv4-overview)
- GKE docs: [About GKE Granular NAT](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/about-granular-nat)
- IPv6.net: [Scaling massive AI/ML workloads with IPv6 on GKE clusters](https://ipv6.net/news/scaling-massive-ai-ml-workloads-with-ipv6-on-google-kubernetes-engine-clusters/)
