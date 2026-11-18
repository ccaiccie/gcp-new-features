# Cloud DNS routing policies: weighted, geolocation and failover with health checks

Terraform practice lab for the GCP New Features video "Cloud DNS Routing Policies: Weighted, Geolocation and Failover with Health Checks" (YouTube playlist **gcp new features**, Network Technician channel).

## What it builds

| Piece | Why it matters |
| --- | --- |
| Public managed zone `dnslab.example.com.` | Routing policies work in public and private zones (not forwarding, peering, reverse or Service Directory zones) |
| Global TCP health check with `source_regions` (3 regions, 30 s interval) | External endpoint checks: 3 regions x 3 probers = 9 probers; interval 30 to 300 s |
| `canary.` A record, `routing_policy { wrr }` 900 / 100 | Weighted round robin: about 90 % / 10 % of answers, statistically, across resolvers |
| `app.` A record, `routing_policy { geo }` europe-west3 and us-east4, health checked | Nearest region answers; if unhealthy, the next closest healthy region (unless geofenced) |
| `ha.` A record, `routing_policy { primary_backup }`, trickle 0.1 | Primary answers while healthy; backup is a geolocation set; trickle keeps it warm |

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0. The lab enables the DNS and Compute APIs.

For real health checking, set `europe_endpoint_ip` and `us_endpoint_ip` to two internet-reachable endpoints (for example two small VMs or regional external load balancers) and **allow the health check port from any source** on them — Cloud DNS probers do not use fixed ranges. With the default documentation addresses every endpoint is unhealthy, which is itself a lesson: when everything is unhealthy, Cloud DNS returns all targets.

## Cost warning

A managed zone, DNS queries and health checks are billed (small amounts); any endpoints you create are extra. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # project, endpoint addresses
terraform init
terraform validate
terraform plan
terraform apply
NS=$(terraform output -json name_servers | jq -r '.[0]')
for i in $(seq 1 20); do dig +short @"$NS" canary.dnslab.example.com; done | sort | uniq -c   # roughly 90/10
dig +short @"$NS" app.dnslab.example.com
dig +short @"$NS" app.dnslab.example.com +subnet=85.214.0.0/24    # a European client subnet (EDNS client subnet)
dig +short @"$NS" ha.dnslab.example.com
```

Then stop the service on the US endpoint (or block the port) and repeat the `app.` and `ha.` queries after a minute or two.

## Experiments

1. Set `canary_new_weight = 0` and `canary_current_weight = 0`: all-zero weights split traffic equally.
2. Set `enable_geo_fencing = true`, make the Europe endpoint unhealthy and query with a European `+subnet`: the answer stays in Europe.
3. Set `trickle_ratio = 1` to force a manual failover of `ha.` to the backup.
4. Enable health check logging (Cloud DNS logging) and find why an endpoint was or was not returned.

## References

- DNS routing policies and health checks — https://cloud.google.com/dns/docs/routing-policies-overview
- Configure DNS routing policies and health checks — https://cloud.google.com/dns/docs/configure-routing-policies
- google_dns_record_set — https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
