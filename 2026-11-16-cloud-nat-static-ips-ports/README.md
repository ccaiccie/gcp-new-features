# Cloud NAT: static addresses, port allocation, rules and logs

Terraform practice lab for the GCP New Features video "Cloud NAT for Network Engineers: Static IPs, Ports, Rules and Logs" (YouTube playlist **gcp new features**, Network Technician channel).

## What it builds

| Piece | Why it matters |
| --- | --- |
| Custom-mode VPC and one subnet | Private Google Access on; the VM has no external IP |
| Two static regional external addresses | A fixed allowlist to hand to a partner |
| Cloud Router and Public NAT gateway, manual NAT IP assignment | The gateway runs on the router control plane; no proxy VMs |
| Dynamic port allocation: min 64, max 1024 ports per VM | A busy VM grows, an idle VM gives ports back; endpoint-independent mapping is off because the two cannot be combined |
| `tcp_time_wait_timeout_sec = 30` | Faster reuse of post-NAT tuples |
| NAT rule 100: destination match uses the partner address | Different egress address for one destination |
| Logging, `ERRORS_ONLY` | Shows drops such as out of resources |
| Optional test VM, IAP SSH firewall rule | Prove egress without an external IP |

## Prerequisites

A Google Cloud project with billing, `gcloud auth application-default login`, Terraform 1.6+, provider `hashicorp/google` 8.11.0.

## Cost warning

Cloud NAT is billed per gateway-hour and per GiB processed, static external addresses are billed while reserved, and the `e2-micro` VM runs while the lab is up. Set `create_vm = false` to skip the VM. **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform plan
terraform apply
$(terraform output -raw client_ssh_command)
curl -s https://ifconfig.me ; echo      # should print default_nat_ip
```

Read the logs under Logs Explorer: resource `nat_gateway`. Check `terraform output default_nat_ip` and `partner_nat_ip`.

## Experiments

1. Change `nat_log_filter` to `ALL` and watch translations appear.
2. Lower `max_ports_per_vm` below `min_ports_per_vm` and read the validation or API error; then raise it again.
3. Switch to static port allocation (`enable_dynamic_port_allocation = false`) and compare how many VMs one address can serve.
4. Point `partner_destination_cidr_ip` at an address you can observe and confirm the partner address is the source.
