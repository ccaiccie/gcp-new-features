#!/usr/bin/env bash
# Watch the migration: cluster state, node pool state, anetd and kube-proxy, every 30 seconds.
set -euo pipefail
: "${PROJECT:?}" "${CLUSTER:?}" "${LOCATION:?}"
while true; do
  date
  echo -n "cluster: "
  gcloud container clusters describe "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(networkConfig.datapathProvider)'
  gcloud container node-pools list --cluster="$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(name, networkConfig.datapathProvider)'
  kubectl get ds -n kube-system anetd 2>/dev/null || echo "anetd: not present yet"
  echo "kube-proxy pods: $(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c kube-proxy || true)"
  kubectl get nodes --no-headers | awk '{print "  " $1, $2}'
  echo
  sleep 30
done
