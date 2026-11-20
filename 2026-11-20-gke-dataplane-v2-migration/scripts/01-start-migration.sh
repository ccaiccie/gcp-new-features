#!/usr/bin/env bash
# Start the in-place migration from Dataplane V1 to GKE Dataplane V2 (Preview).
set -euo pipefail
: "${PROJECT:?}" "${CLUSTER:?}" "${LOCATION:?}"
gcloud container clusters update "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --enable-dataplane-v2
gcloud container clusters describe "$CLUSTER" --project="$PROJECT" --location="$LOCATION" --format='value(networkConfig.datapathProvider)'
# Expected now: MIGRATE_TO_ADVANCED_DATAPATH
