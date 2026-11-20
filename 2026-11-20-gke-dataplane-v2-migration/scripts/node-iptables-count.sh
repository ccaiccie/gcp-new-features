#!/usr/bin/env bash
# Count kube-proxy iptables rules on one node (run before and after the migration).
set -euo pipefail
: "${PROJECT:?}" "${LOCATION:?}"
NODE=${1:-$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')}
gcloud compute ssh "$NODE" --project="$PROJECT" --zone="$LOCATION" --tunnel-through-iap \
  --command='echo "KUBE- iptables rules: $(sudo iptables-save | grep -c "^-A KUBE-")"'
