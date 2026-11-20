#!/usr/bin/env bash
# Preflight checklist for in-place migration to GKE Dataplane V2 (Preview).
# Needs: PROJECT, CLUSTER, LOCATION (see `terraform output -raw env_for_scripts`).
set -euo pipefail
: "${PROJECT:?}" "${CLUSTER:?}" "${LOCATION:?}"

echo "== 1. Datapath, routing mode and Calico network policy =="
gcloud container clusters describe "$CLUSTER" --project="$PROJECT" --location="$LOCATION" \
  --format='table(networkConfig.datapathProvider, ipAllocationPolicy.useIpAliases, networkPolicy.enabled, addonsConfig.networkPolicyConfig.disabled)'
echo "Want: LEGACY_DATAPATH (or empty), useIpAliases True (VPC-native), networkPolicy.enabled empty/False."

echo "== 2. Versions (control plane 1.35.3-gke.1155000+, node pools 1.35.1-gke.1516000+) =="
gcloud container clusters describe "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(currentMasterVersion)'
gcloud container node-pools list --cluster="$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='table(name, version, upgradeSettings.maxSurge, upgradeSettings.maxUnavailable)'

echo "== 3. Existing NetworkPolicies (remove them first: Dataplane V2 always enforces NetworkPolicy) =="
kubectl get networkpolicy --all-namespaces || true

echo "== 4. Istio / Cloud Service Mesh version (needs 1.23+ if used) =="
kubectl get pods -n istio-system -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null || echo "no istio-system namespace"

echo "== 5. Active Assist recommendations for this project's GKE clusters =="
echo "Console: Kubernetes Engine > Clusters > $CLUSTER > Recommendations (or the Recommendation Hub)."
gcloud recommender recommendations list --project="$PROJECT" --location="$LOCATION" \
  --recommender=google.container.DiagnosisRecommender --format='table(name.basename(), description)' 2>/dev/null \
  || echo "Could not list with gcloud; check the cluster details page."

echo "== 6. Pod IP headroom for the surge nodes =="
echo "Console: Kubernetes Engine > Clusters > $CLUSTER > Observability / IP address utilization insights."
kubectl get nodes -o custom-columns=NAME:.metadata.name,POD_CIDR:.spec.podCIDR
