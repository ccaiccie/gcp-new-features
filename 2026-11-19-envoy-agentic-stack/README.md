# The Envoy agentic stack: routing models, tokens, and MCP

Terraform practice lab for the GCP New Features video "The Envoy Agentic Stack: Routing Models, Tokens and MCP" (YouTube playlist **gcp new features**, Network Technician channel).

The lesson is based on the Google Cloud post [The Envoy agentic stack: Routing models, tokens, and MCP](https://cloud.google.com/blog/products/networking/the-envoy-agentic-stack-routing-models-tokens-and-mcp) (18 November 2026). That post describes Envoy capabilities for body parsing, token-aware quotas, model and MCP routing, and security callouts. This lab provisions only what the `hashicorp/google` provider can actually create.

## What it builds

| Piece | Why it matters |
| --- | --- |
| VPC and a `/24` subnet (`10.19.0.0/24`) | A lab network. This CIDR is an example for the exercise, not a range from the post |
| Two `e2-micro` Debian VMs, no public IPs | Stand-ins for a model backend and an MCP backend. Each serves a one-line HTTP page |
| Global external Application Load Balancer (`EXTERNAL_MANAGED`) | This is Google Cloud's Envoy-based Application Load Balancer |
| URL map | `/v1` and `/v1/*` go to the model stand-in; `/mcp` and `/mcp/*` go to the MCP stand-in. This is classic Layer 7 URI routing |
| `google_compute_security_policy` | A Cloud Armor **request-count** throttle. When the source IP exceeds the threshold, the policy returns HTTP 429 |
| Firewall | Allows Google health-check ranges `130.211.0.0/22` and `35.191.0.0/16` to port 80, and optional IAP SSH |

The default Cloud Armor threshold is 10 requests per 60 seconds so a short `curl` loop can show the 429. That limit is a lab convenience, not a value from the post.

## What this lab cannot build

The Google provider (this lab pins `hashicorp/google` 8.11.0) does not expose the agent-specific Envoy features described in the post. **Do not treat the lab as a complete agentic stack.** Missing, and not fabricated here:

- Native wire-format body parsing and transcoding across OpenAI, Anthropic, and Gemini schemas
- Token-aware rate limiting (tokens per minute / tokens per day), pre-inference token estimation, and a quota database
- KV-cache prefix affinity, Kubernetes Gateway API Inference Extensions, and Endpoint Picker (EPP) model dispatch
- MCP routing on `Mcp-Method` and `Mcp-Name` headers, and the HTTP 400 / `-32020` (HeaderMismatch) backend check from the 2026-07-28 MCP specification
- `ext_proc` callouts to Model Armor, ShieldGemma, or DLP
- Agent Substrate scale-to-zero resume, and Envoy buffering a first packet while a microVM or gVisor sandbox is resumed
- Egress allowlists of verified domains for agent environments, as described in the post

Cloud Armor in this lab counts **requests**, not tokens. That is the request-rate limiting fallacy the post warns about: a single huge prompt still counts as one request. Use the 429 you get here to see a reject at the Envoy-based load balancer, then go back to the lesson for token-aware behaviour, which this provider cannot provision.

The post does not label these Envoy capabilities as Preview or as generally available Google Cloud product switches. This README does not invent that status.

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0. Compute Engine API is enabled by the lab if it is not already on.

## Cost warning

The lab creates a reserved global external IPv4 address, two `e2-micro` VMs, an Application Load Balancer, and a Cloud Armor policy (billed per policy, rule, and request once traffic arrives). **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform plan
terraform apply
terraform output
```

Give the VMs a minute to boot and pass health checks, then:

```bash
# Path routing: different backends for /v1 and /mcp
curl -sS "$(terraform output -raw model_url)"
curl -sS "$(terraform output -raw mcp_url)"

# Request-count 429 (not token-aware). Stop when you start seeing 429.
eval "$(terraform output -raw try_rate_limit)"
```

You should see the model stand-in text on `/v1/chat/completions`, the MCP stand-in text on `/mcp`, and HTTP 429 after the Cloud Armor request-count threshold is exceeded.

## Experiments

1. Compare the two paths. `/v1/chat/completions` and `/mcp` hit different VMs because of the URL map, not because Envoy parsed a JSON `model` field or an `Mcp-Name` header.
2. Trip the 429, then wait for the interval to elapse and confirm requests are allowed again.
3. Optional: raise or lower `rate_limit_count` in `terraform.tfvars` and re-apply.

## Clean up

```bash
terraform destroy
```
