#!/usr/bin/env bash
# Shows recent load balancer log entries for mTLS client certificate validation.
# Rejected handshakes are logged with status 0 and a client_cert_* statusDetails value.
# Usage: ./scripts/show-mtls-logs.sh [forwarding rule name, default mtls-https] [freshness, default 30m]
set -euo pipefail
FR="${1:-mtls-https}"
FRESH="${2:-30m}"
gcloud logging read \
  "jsonPayload.statusDetails=~\"client_cert\" AND jsonPayload.@type=\"type.googleapis.com/google.cloud.loadbalancing.type.LoadBalancerLogEntry\" AND resource.labels.forwarding_rule_name=\"${FR}\"" \
  --freshness="$FRESH" --limit=20 \
  --format='table(timestamp, jsonPayload.statusDetails, httpRequest.status)'
