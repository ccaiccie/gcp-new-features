# In-place migration to GKE Dataplane V2 (Preview)

Terraform practice lab for the GCP New Features video "In-place migration to GKE Dataplane V2" (YouTube playlist **gcp new features**, Network Technician channel).

GKE Dataplane V2 is built on eBPF and Cilium and replaces iptables and kube-proxy. Since November 19, 2026, eligible **VPC-native** clusters can move from Dataplane V1 (the legacy datapath) to Dataplane V2 **in place** (Preview), instead of building a new cluster. This lab builds a small VPC-native cluster on the legacy datapath, runs the preflight checklist, starts the migration with `gcloud`, watches the node pools roll, shows where rollback is still possible, and proves Dataplane V2 by enforcing a NetworkPolicy and counting iptables rules before and after.

## Terraform limitation (read first)

- In `hashicorp/google` **8.12.0** and `hashicorp/google-beta` **8.12.0** (latest on November 20, 2026), `google_container_cluster.datapath_provider` is **ForceNew**. Changing it from `LEGACY_DATAPATH` to `ADVANCED_DATAPATH` in Terraform would **destroy and recreate the cluster**, not migrate it.
- Google's migration guide says the same thing: *you can't use Terraform to migrate to GKE Dataplane V2.*
- So Terraform only builds the starting point. The migration, the optional node pool patch and the rollback are `gcloud` commands in `scripts/`.
- The cluster resource has `lifecycle { ignore_changes = [datapath_provider] }`. During the migration the API reports `MIGRATE_TO_ADVANCED_DATAPATH`, and afterwards `ADVANCED_DATAPATH`; without the ignore, the next `terraform plan` would propose replacing your freshly migrated cluster. In your own code, add the same ignore (or update the value to `ADVANCED_DATAPATH` only after finalization) **before** you migrate.
- There is no separate finalize command: GKE finalizes automatically after every node pool is on Dataplane V2.
- `terraform validate` warns that `remove_default_node_pool` is deprecated for 1.36.4-gke.1469000+; it still works, and keeps the lab correct on older 1.35 control planes.

## What it builds

| Piece | Why it matters |
| --- | --- |
| VPC `dpv2-vpc`, subnet `10.10.0.0/24` with secondary ranges `pods` `10.20.0.0/21` and `services` `10.30.0.0/24` | VPC-native (alias IP) is required; routes-based clusters can't migrate |
| Cluster `dpv2-cluster` (zonal), `datapath_provider = "LEGACY_DATAPATH"`, Calico network policy **off**, REGULAR channel | Dataplane V1 starting point; clusters with Calico network policy enabled can't migrate directly |
| Node pool `dpv2-pool`: 2 x `e2-standard-2`, surge `max_surge = 1`, `max_unavailable = 0` | The migration recreates nodes with your upgrade strategy, so surge nodes need Pod IP headroom: a /21 holds eight /24 node ranges |
| Optional weekend maintenance window (`enable_maintenance_window = true`) | The migration respects windows and exclusions, so it can look stalled outside the window |
| Firewall: SSH from IAP `35.235.240.0/20` | Lets you count kube-proxy iptables rules on a node |

## Prerequisites

- A Google Cloud project with billing, and permission to create Compute Engine and GKE resources.
- `gcloud` (up to date), `kubectl`, Terraform 1.6+.
- Eligibility for migration: control plane **1.35.3-gke.1155000 or later**, node pools **1.35.1-gke.1516000 or later**; if you use Cloud Service Mesh or Istio, **1.23 or later**.

## Cost warning

GKE cluster management fee plus two `e2-standard-2` VMs (three during surge). **Run `terraform destroy` when you finish.**

## Steps

```bash
cp terraform.tfvars.example terraform.tfvars     # set project_id
terraform init && terraform validate && terraform apply
$(terraform output -raw get_credentials_command)
eval "$(terraform output -raw env_for_scripts)"  # sets PROJECT CLUSTER LOCATION POOL
kubectl apply -f k8s/app.yaml
```

### 1. Before: Dataplane V1

```bash
$(terraform output -raw datapath_status_command)          # LEGACY_DATAPATH (or empty on older versions)
kubectl get pods -n kube-system | grep kube-proxy          # one kube-proxy Pod per node
kubectl get ds -n kube-system anetd                        # NotFound
./scripts/node-iptables-count.sh                           # dozens of KUBE- rules
kubectl -n dpv2-lab exec client-denied -- /agnhost connect web.dpv2-lab.svc.cluster.local:80 --timeout=3s && echo reachable
```

### 2. Preflight checklist

```bash
./scripts/00-preflight.sh
```

Work through each item: VPC-native and no Calico network policy; versions; **remove existing NetworkPolicies** (Dataplane V2 always enforces them, so a policy that was ignored on V1 would suddenly apply when nodes are recreated); Istio 1.23+; Active Assist recommendations (custom CNI plugins or custom eBPF programs on managed interfaces); Pod IP headroom in GKE IP address utilization insights. Enable features such as NodeLocal DNSCache or intranode visibility **before** or **after**, never during, the migration.

### 3. Start the migration

```bash
./scripts/01-start-migration.sh     # gcloud container clusters update ... --enable-dataplane-v2
./scripts/02-watch.sh               # Ctrl+C to stop
```

Expect the cluster to show `MIGRATE_TO_ADVANCED_DATAPATH`, `anetd` to appear, then node pools to switch to `ADVANCED_DATAPATH` while nodes are replaced one at a time (surge 1). Cluster-wide networking settings are locked until it completes, and the migration **ignores PodDisruptionBudgets**, so run it in a quiet period.

### 4. Optional: patch the node pool yourself

```bash
./scripts/03-patch-node-pool.sh     # gcloud container node-pools update $POOL ... --datapath-provider=advanced-datapath
```

With several pools, patch one sequentially first and check workloads before running patches concurrently.

### 5. Optional: roll back (only before finalization)

```bash
./scripts/04-rollback.sh            # cancels running UPGRADE_NODES operations, then --no-enable-dataplane-v2
```

The script refuses once the cluster shows `ADVANCED_DATAPATH`, because a finalized migration can't be reverted. After a rollback, start again with step 3.

### 6. After: Dataplane V2

```bash
$(terraform output -raw datapath_status_command)          # ADVANCED_DATAPATH
kubectl get ds -n kube-system anetd                        # one anetd per node
kubectl get pods -n kube-system | grep kube-proxy          # none
./scripts/node-iptables-count.sh                           # KUBE- rules gone (Services are eBPF map lookups now)
terraform plan                                             # no changes: datapath_provider is ignored

kubectl apply -f k8s/netpol-after-migration.yaml
kubectl -n dpv2-lab exec client-allowed -- /agnhost connect web.dpv2-lab.svc.cluster.local:80 --timeout=3s && echo allowed
kubectl -n dpv2-lab exec client-denied  -- /agnhost connect web.dpv2-lab.svc.cluster.local:80 --timeout=3s || echo blocked
```

The `client-denied` connection now fails: NetworkPolicy is enforced in the kernel by eBPF, with no Calico add-on.

## Experiments

1. **Maintenance windows.** Recreate with `enable_maintenance_window = true` and start the migration on a weekday: the node pool waits for the weekend window. Patch it manually (step 4) to skip the wait.
2. **IP headroom.** Do the arithmetic for `node_count = 8` with the /21 Pod range: all eight /24 node ranges are in use, so a surge node would have no Pod range left. Check GKE IP address utilization insights and size Pod ranges for your surge settings before you migrate (this lab does not try to trigger the failure).
3. **Observability.** After finalization, enable Dataplane V2 observability (`gcloud container clusters update $CLUSTER --location=$LOCATION --enable-dataplane-v2-flow-observability`) and network policy logging, which the guide says to configure after migrating.

## Cleanup

```bash
kubectl delete -f k8s/netpol-after-migration.yaml -f k8s/app.yaml --ignore-not-found
terraform destroy
```

## Sources

- Google Cloud blog, November 19, 2026: [Introducing in-place migration to GKE Dataplane V2](https://cloud.google.com/blog/products/networking/gke-dataplane-v2-in-place-migration)
- [About migrating to GKE Dataplane V2](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/about-migrating-dataplane-v2)
- [Migrate VPC-native clusters to GKE Dataplane V2](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/migrate-dataplane-v2)
- [GKE Dataplane V2 concepts](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2)
- Provider source: `datapath_provider` is `ForceNew: true` in [terraform-provider-google v8.12.0](https://github.com/hashicorp/terraform-provider-google/blob/v8.12.0/google/services/container/resource_container_cluster.go)
