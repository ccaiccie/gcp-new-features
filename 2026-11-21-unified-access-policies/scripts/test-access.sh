#!/usr/bin/env bash
# Tests the lab Unified Access Policy by impersonating the two lab service accounts.
# Usage: ./scripts/test-access.sh PROJECT_ID NETOPS_SA BREAKGLASS_SA NETWORK
set -u
P="${1:?project}"; NETOPS="${2:?netops sa}"; BG="${3:?breakglass sa}"; NET="${4:?network}"
RULE="uap-test-allow-ssh-$(date +%s)"

try() {
  local label="$1"; shift
  echo "=== ${label}"
  if out=$("$@" 2>&1); then echo "ALLOWED"; else echo "DENIED: $(echo "$out" | grep -m1 -iE 'permission|denied|forbidden|error' || echo "$out" | tail -1)"; fi
  echo
}

try "1. netops lists firewall rules (UAP allow rule: networkViewer)" \
  gcloud compute firewall-rules list --project="$P" --impersonate-service-account="$NETOPS" --format="value(name)"

try "2. netops creates a firewall rule (allow policy says yes; UAP deny rule says no)" \
  gcloud compute firewall-rules create "${RULE}-netops" --project="$P" --network="$NET" \
    --allow=tcp:22 --source-ranges=35.235.240.0/20 --impersonate-service-account="$NETOPS" --quiet

try "3. break-glass creates a firewall rule (excluded principal)" \
  gcloud compute firewall-rules create "${RULE}-bg" --project="$P" --network="$NET" \
    --allow=tcp:22 --source-ranges=35.235.240.0/20 --impersonate-service-account="$BG" --quiet

try "4. netops reads that rule (firewalls.get is an excluded permission in the deny rule)" \
  gcloud compute firewall-rules describe "${RULE}-bg" --project="$P" --impersonate-service-account="$NETOPS" --format="value(name)"

try "5. break-glass deletes the test rule (cleanup)" \
  gcloud compute firewall-rules delete "${RULE}-bg" --project="$P" --impersonate-service-account="$BG" --quiet
