#!/usr/bin/env bash
# Optional: expedite by patching one node pool now instead of waiting for the automated rollout.
# Patch pools one at a time first; only run concurrent patches after a sequential one looked healthy.
set -euo pipefail
: "${PROJECT:?}" "${CLUSTER:?}" "${LOCATION:?}" "${POOL:?}"
gcloud container node-pools update "$POOL" --cluster="$CLUSTER" --project="$PROJECT" --location="$LOCATION" \
  --datapath-provider=advanced-datapath
