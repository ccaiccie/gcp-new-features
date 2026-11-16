# Cloud Armor at the CDN edge: ASN, Network Threat Intelligence, and HTTP filters

Terraform practice lab for the GCP New Features video "Cloud Armor at the CDN Edge: ASN, Threat Intelligence and HTTP Filters" (YouTube playlist **gcp new features**, Network Technician channel).

As of 16 November 2026, globally scoped Cloud Armor edge security policies for Cloud CDN edge cache services can match client ASNs, Network Threat Intelligence (NTI) lists, and HTTP attributes. This feature is in **Preview**.

## What it builds

| Piece | Why it matters |
| --- | --- |
| Cloud Storage bucket | A cheap origin. The bucket stays private; this lab is about the policy, not a public site |
| Backend bucket with Cloud CDN enabled | The target an edge policy can attach to (backend buckets cannot take a backend security policy) |
| `google_compute_security_policy` with `type = "CLOUD_ARMOR_EDGE"` | Evaluated at the outermost perimeter, upstream of the Cloud CDN cache |
| Priority 1000: `origin.asn == var.denied_asn` | ASN matching. Default `64512` is a documentation placeholder you replace after investigation |
| Priority 1300: `request.path.startsWith(var.denied_path_prefix)` | HTTP path filter (`/lab-blocked` by default) |
| Priority 1400: header `x-lab-block == 1` | HTTP header filter using `has(request.headers[...])` |
| Priority 2147483647: default allow | Required default rule |
| Optional priorities 1100 and 1200: NTI denies | `iplist-tor-exit-nodes` and `iplist-known-malicious-ips`; off by default because they require Cloud Armor Enterprise |

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0.

Network Threat Intelligence rules require a Cloud Armor Enterprise subscription in the project. Leave `enable_threat_intelligence = false` on Standard tier.

## Cost warning

A Cloud Storage bucket and a Cloud Armor security policy can incur charges (storage is tiny here; Cloud Armor is billed per policy, rule, and request if the policy is attached and receiving traffic). There is no VM and no reserved external IP in the default lab. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform plan
terraform apply
terraform output
```

The apply already attaches the policy to the backend bucket. Equivalent gcloud, if you were doing it by hand:

```bash
gcloud compute security-policies create armor-edge-policy --type=CLOUD_ARMOR_EDGE --global

gcloud compute security-policies rules create 1000 \
  --security-policy=armor-edge-policy \
  --expression='origin.asn == 64512' \
  --action=deny-403

gcloud compute backend-buckets update armor-edge-backend \
  --edge-security-policy=armor-edge-policy

# For a Cloud CDN-enabled backend service instead of a bucket:
gcloud compute backend-services update BACKEND_SERVICE \
  --edge-security-policy=armor-edge-policy
```

Put new denies in preview mode (`--preview` or `preview = true` in Terraform) and review Cloud Armor logs before you enforce them.

## Experiments

1. Change `denied_asn` to an ASN you have actually investigated. Do not copy a random operator into a deny rule.
2. Set `enable_threat_intelligence = true` only after you confirm Cloud Armor Enterprise, then plan and apply the Tor and known-malicious denials.
3. Add a rule in preview mode for `request.path.startsWith('/admin')` and inspect the logs before turning preview off.
4. If you already have a global external Application Load Balancer and a CDN-enabled backend service, attach the same policy with `--edge-security-policy` and confirm that a cache hit is still blocked by an edge deny (a backend deny would not see that hit).

## Sources

- https://docs.cloud.google.com/armor/docs/release-notes#November_16_2026
- https://docs.cloud.google.com/armor/docs/security-policy-overview
- https://docs.cloud.google.com/armor/docs/threat-intelligence
- https://docs.cloud.google.com/armor/docs/manage-security-policies
- https://docs.cloud.google.com/armor/docs/create-security-policy-rules
