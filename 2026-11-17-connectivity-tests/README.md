# Connectivity Tests: trace a packet through your Google Cloud network

Terraform practice lab for the GCP New Features video "Connectivity Tests: Trace a Packet Through Your Google Cloud Network" (YouTube playlist **gcp new features**, Network Technician channel).

## What it builds

| Piece | Why it matters |
| --- | --- |
| Network Management API and Compute Engine API | Connectivity Tests is served by the Network Management API |
| Custom-mode VPC, subnets A and B | Subnet routes carry the packet between the two subnets |
| Two `e2-micro` VMs without external IPs (tags `app`, `web`) | Instance endpoints for the tests |
| Firewall rule: tcp/8080 from subnet A to tag `web` | The only ingress allow; everything else hits the implied deny ingress rule |
| Test `…-8080` with `round_trip = true` | Expected **REACHABLE**, with a separate return-path result |
| Test `…-5432` | Expected **UNREACHABLE**, dropped at ingress by the implied deny rule |

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0. Your identity needs permission to create the resources and the Network Management Admin role (`roles/networkmanagement.admin`) to create tests; without visibility of every resource in the path a test returns `UNDETERMINED`.

## Cost warning

The two `e2-micro` VMs run while the lab exists; Connectivity Tests runs are billed per test run (check current pricing). **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform validate
terraform plan
terraform apply
terraform output describe_commands
```

Open **Network Intelligence Center → Connectivity Tests** in the console, or run the `describe` commands. The 8080 test should be reachable; the 5432 test should be unreachable with the drop at the ingress firewall step.

## Experiments

1. Add `"5432"` to the firewall rule's ports, apply, **wait 2 minutes** (changes take 20–120 seconds to reach the analysis), then rerun: `gcloud network-management connectivity-tests rerun ctlab-a-to-b-5432`.
2. Set `bypass_firewall_checks = true` on the blocked test and compare: routing alone delivers the packet.
3. Stop VM B and rerun the allowed test; look at what the live data plane analysis reports.
4. Point a test at an internet address such as `8.8.8.8` from VM A (no external IP, no Cloud NAT) and read the drop reason.

## References

- Connectivity Tests overview — https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/concepts/overview
- Create and run Connectivity Tests — https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests
- ConnectivityTest REST resource — https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/reference/networkmanagement/rest/v1/projects.locations.global.connectivityTests
