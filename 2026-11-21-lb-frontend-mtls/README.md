# Frontend mTLS on a global external Application Load Balancer

Practice lab for the **Frontend mutual TLS on Google Cloud Application Load Balancers** lesson (Network Technician, GCP new features, November 21, 2026).

The load balancer asks every client for a certificate, validates it against a Certificate Manager **trust config**, and then follows the **client validation mode** in a Network Security **ServerTlsPolicy** (the console calls it *Client Authentication*). After validation, the load balancer adds **custom mTLS request headers** so the backend can see what happened. A small header-echo VM shows you those headers.

```
client (curl + cert) --TLS 1.x, client cert--> global external ALB (EXTERNAL_MANAGED)
                                                 target HTTPS proxy
                                                   server_tls_policy -> ServerTlsPolicy (mtls_policy)
                                                                         -> trust config (root + intermediate)
                                                 backend service + custom X-Client-Cert-* headers
                                                   -> echo VM :8080 (prints the headers)
```

## What Terraform builds

Everything uses real resources from `hashicorp/google` 8.12.0, `hashicorp/tls` and `hashicorp/local`. There is no provider gap for this feature.

| File | Resources |
| --- | --- |
| `pki.tf` | Lab PKI: root CA, issuing (intermediate) CA, three client certificates (`good`, `noeku`, `serveronly`), a separate rogue root with its own client, and a self-signed server certificate. Writes client keys and certificates to `./certs/` (ignored by git). |
| `main.tf` | APIs; VPC, subnet, firewall rules for the Google Front End/health check ranges and IAP SSH; echo VM in an unmanaged instance group; health check; `EXTERNAL_MANAGED` backend service with mTLS custom request headers and logging; URL map; `google_certificate_manager_trust_config` (location `global`); `google_network_security_server_tls_policy` with `mtls_policy`; `google_compute_ssl_certificate`; `google_compute_target_https_proxy` with `server_tls_policy`; global address and forwarding rule on 443. |
| `scripts/test-clients.sh` | Six curl tests: no certificate, good, no EKU, serverAuth-only EKU, rogue CA, and a header spoofing attempt. |
| `scripts/show-mtls-logs.sh` | Reads load balancer logs with `jsonPayload.statusDetails=~"client_cert"`. |

The client certificates used in the tests:

| Certificate | Issued by | Extended Key Usage | What it demonstrates |
| --- | --- | --- | --- |
| `good` | lab issuing CA | clientAuth | Valid chain. curl sends only the leaf; the load balancer builds the chain with the intermediate from the trust store. Has a SPIFFE ID URI SAN. |
| `noeku` | lab issuing CA | none (extension absent) | Fails strict validation; passes with the `ALLOW_MISSING_EKU` relaxation. |
| `serveronly` | lab issuing CA | serverAuth only | Rejected even with `ALLOW_MISSING_EKU`, because an EKU is present without clientAuth. |
| `rogue` | rogue root (not trusted) | clientAuth | No chain of trust to the trust anchor. |

## Prerequisites

- A Google Cloud project with billing enabled, and permission to enable APIs and create Compute Engine, Certificate Manager and Network Security resources (Project Owner, or Compute Network Admin + Compute Security Admin + Compute Instance Admin + Certificate Manager Owner + Network Security Admin in a lab project).
- Terraform 1.6 or later, the Google Cloud CLI, and curl built with OpenSSL.
- **Cost:** one e2-micro VM, one global forwarding rule and load balancer data processing, and logs. Destroy the lab when you finish.
- **Security:** the private keys are lab keys. They are stored in Terraform state and in `./certs/`. Do not reuse them, and do not commit state, `terraform.tfvars` or `certs/` (the repository and folder `.gitignore` files exclude them).

## Steps

1. Configure and deploy:

   ```bash
   cp terraform.tfvars.example terraform.tfvars   # set project_id
   terraform init
   terraform apply
   ```

2. Wait until the backend is healthy (the VM installs nothing; the service starts in about a minute), then run the tests:

   ```bash
   gcloud compute backend-services get-health mtls-backend --global
   ./scripts/test-clients.sh "$(terraform output -raw lb_ip)" "$(terraform output -raw server_hostname)"
   ```

   A new load balancer can take several minutes before it serves traffic. If every test fails, wait and run it again.

3. Read the logged failures:

   ```bash
   ./scripts/show-mtls-logs.sh mtls-https 30m
   ```

   Connections closed during validation are logged with status `0` and a `statusDetails` value such as `client_cert_not_provided`, `client_cert_chain_invalid_eku` or `client_cert_validation_failed`.

## Experiments: the three client validation modes

Change `client_validation_mode` (and the relaxations) in `terraform.tfvars`, run `terraform apply`, then run the test script again. The ServerTlsPolicy is updated in place. Expected results, taken from the Google Cloud documentation (verify them in your own project):

| Test | `REJECT_INVALID` (default) | `ALLOW_INVALID_OR_MISSING_CLIENT_CERT` | `ALLOW_VALIDATION_RELAXATIONS` + `ALLOW_MISSING_EKU` |
| --- | --- | --- | --- |
| no certificate | connection closed | reaches backend, `Present: false` | connection closed |
| good | reaches backend, `Chain-Verified: true` | reaches backend, `Chain-Verified: true` | reaches backend |
| noeku | connection closed | reaches backend, `Chain-Verified: false` plus an error | reaches backend |
| serveronly | connection closed | reaches backend, `Chain-Verified: false` plus an error | connection closed |
| rogue | connection closed | reaches backend, `Chain-Verified: false` plus an error | connection closed |
| spoofed headers, no certificate | connection closed | reaches backend; the load balancer **overwrites** the fake `X-Client-Cert-*` headers | connection closed |

Things to notice:

- In `ALLOW_INVALID_OR_MISSING_CLIENT_CERT` mode, the load balancer is no longer the enforcement point. Your backend must check `X-Client-Cert-Chain-Verified` on every request. Headers added by the load balancer overwrite client headers with the same name, which is why the spoof test fails.
- Proof of private key possession is always checked. A client that presents a certificate without the matching key fails the handshake in every mode.
- `ALLOW_VALIDATION_RELAXATIONS` (generally available November 2, 2026) requires at least one relaxation. Google recommends it only as a temporary migration aid; `ALLOW_SHA1_HASHING` and `ALLOW_EXPIRED_LEAF_CERTIFICATE` are flagged as insecure. The lab adds a Terraform precondition that refuses this mode without a relaxation.

## Limits worth knowing (from the documentation)

- The load balancer does **not** check client certificate revocation (no CRL or OCSP). Remove trust or use an allowlist strategy and short-lived certificates instead.
- Client (leaf) certificates must not be self-signed, must not be expired (unless relaxed) and need EKU clientAuth (unless the EKU extension is absent and `ALLOW_MISSING_EKU` is set). RSA 2048 to 4096 bits or ECDSA P-256/P-384, SHA-256 or stronger.
- Trust store: up to 200 trust anchors and intermediates combined (at most 100 intermediates), plus up to 500 allowlisted certificates. Chain depth up to 10. The client's chain is limited to 16 KB and 10 certificates.
- The client has 10 seconds to present its certificate during the handshake.
- Custom request headers: at most 16 (8 KB) per backend service. This lab uses 7.

## Clean up

```bash
terraform destroy
```

`terraform destroy` also removes the generated files in `./certs/`.

## Sources

- Mutual TLS overview: https://cloud.google.com/load-balancing/docs/mtls
- Set up mTLS with user-provided certificates: https://cloud.google.com/load-balancing/docs/https/setting-up-mtls-global-ext-https
- Trust configs: https://cloud.google.com/certificate-manager/docs/trust-configs
- Custom headers and mTLS variables: https://cloud.google.com/load-balancing/docs/https/custom-headers
- Logging for external Application Load Balancers: https://cloud.google.com/load-balancing/docs/https/https-logging-monitoring
- Cloud Load Balancing release notes (validation relaxations GA, November 2, 2026): https://cloud.google.com/load-balancing/docs/release-notes
- Terraform: `google_network_security_server_tls_policy`, `google_certificate_manager_trust_config`, `google_compute_target_https_proxy` in hashicorp/google 8.12.0
