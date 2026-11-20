#!/usr/bin/env bash
# Roll back to Dataplane V1. Only possible BEFORE GKE finalizes the migration (cluster shows ADVANCED_DATAPATH).
set -euo pipefail
: "${PROJECT:?}" "${CLUSTER:?}" "${LOCATION:?}"

state=$(gcloud container clusters describe "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(networkConfig.datapathProvider)')
echo "cluster datapath: $state"
if [ "$state" = "ADVANCED_DATAPATH" ]; then
  echo "Migration is finalized; you can't revert to Dataplane V1." >&2
  exit 1
fi

kubectl get ds -n kube-system anetd || true

echo "Running node upgrade operations that would block the rollback:"
gcloud container operations list --project="$PROJECT" --location="$LOCATION" \
  --filter="operationType=UPGRADE_NODES AND status=RUNNING AND targetLink:*/clusters/$CLUSTER" --format='value(name)' | while read -r op; do
  [ -n "$op" ] && gcloud container operations cancel "$op" --project="$PROJECT" --location="$LOCATION"
done

gcloud container clusters update "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --no-enable-dataplane-v2
gcloud container node-pools list --cluster="$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(name, networkConfig.datapathProvider)'
# Patched pools go back to LEGACY_DATAPATH; GKE then finalizes the cluster as LEGACY_DATAPATH.
