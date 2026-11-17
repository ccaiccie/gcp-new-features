# Cloud Load Balancing: post-quantum TLS key exchange (Phase 2)

Terraform practice lab for the GCP New Features video "Cloud Load Balancing: post-quantum TLS is on by default (Phase 2)" (YouTube playlist **gcp new features**, Network Technician channel).

As of October 2026, Cloud Load Balancing is in **Phase 2** of the post-quantum TLS key exchange rollout. Supported Application Load Balancers and external proxy Network Load Balancers use the hybrid group `X25519MLKEM768` by default on the **frontend** (client to load balancer) when the client advertises TLS 1.3 and that group. You can defer (opt out) with an SSL policy until October 2027. After that date, post-quantum key exchange is always on and deferral no longer works.

## What it builds

| Piece | Why it matters |
| --- | --- |
| `google_compute_ssl_policy.keep` | `post_quantum_key_exchange = "DEFAULT"`: Phase 2 behavior, allow the hybrid group |
| `google_compute_ssl_policy.deferred` | `post_quantum_key_exchange = "DEFERRED"`: refuse the hybrid group until October 2027 |
| Backend bucket and URL map | A cheap origin for a global external Application Load Balancer; the bucket stays private |
| Self-signed certificate | Enough to create a target HTTPS proxy in a lab. Not for any real site |
| `google_compute_target_https_proxy` | Where the SSL policy is attached. This is the frontend TLS control point |
| Reserved global IPv4 address and HTTPS forwarding rule | Completes the load balancer so you can compare Default and Deferred |

Set `create_load_balancer = false` if you only want the two SSL policies.

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0 (this is the version that this repo's labs use; `post_quantum_key_exchange` has been in the provider since 7.34.0).

## Cost warning

The default lab reserves a **global external IPv4 address** and creates a forwarding rule, a target proxy, a URL map, a certificate, a backend bucket, and a Cloud Storage bucket. Reserved external IPs incur a charge while they exist, and the load balancer itself is billable. **Run `terraform destroy` when you finish.** The self-signed certificate is for lab use only.

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform plan
terraform apply
terraform output
```

The apply attaches the policy selected by `ssl_policy_mode` (default: `default`). To switch to the temporary opt-out:

```bash
# in terraform.tfvars
ssl_policy_mode = "deferred"
terraform apply
```

Equivalent gcloud, if you were doing it by hand:

```bash
gcloud compute ssl-policies create pq-tls-keep \
    --profile=MODERN \
    --min-tls-version=1.2 \
    --post-quantum-key-exchange=DEFAULT

gcloud compute ssl-policies create pq-tls-deferred \
    --profile=MODERN \
    --min-tls-version=1.2 \
    --post-quantum-key-exchange=DEFERRED

gcloud compute target-https-proxies update pq-tls-https-proxy \
    --ssl-policy=pq-tls-keep

# Temporary deferral:
gcloud compute target-https-proxies update pq-tls-https-proxy \
    --ssl-policy=pq-tls-deferred
```

You can also set the field on an existing policy:

```bash
gcloud compute ssl-policies update POLICY_NAME --post-quantum-key-exchange=DEFERRED
```

## Experiments

1. Leave `ssl_policy_mode = "default"` and, from a client that offers TLS 1.3 and `X25519MLKEM768`, inspect the handshake and confirm that the selected group is `X25519MLKEM768`.
2. From a TLS 1.2 only client, confirm that the handshake still completes with the usual key exchange. Phase 2 does not force that client onto the hybrid group.
3. Set `ssl_policy_mode = "deferred"`, apply, and confirm that the hybrid group is no longer selected.
4. If you have a TLS-inspecting firewall or proxy on the path, test from behind it. A lab laptop on the public internet will not show a middlebox failure.
5. Switch back to `default` before October 2027. After that date, `DEFERRED` no longer has any effect.

Post-quantum key exchange applies only to frontend TLS (client to load balancer). This lab does not change, and cannot show, key exchange on the load balancer to backend connection.

## Sources

- https://cloud.google.com/load-balancing/docs/release-notes
- https://docs.cloud.google.com/load-balancing/docs/post-quantum-tls
- https://docs.cloud.google.com/load-balancing/docs/ssl-policies-concepts
- https://docs.cloud.google.com/load-balancing/docs/use-ssl-policies
