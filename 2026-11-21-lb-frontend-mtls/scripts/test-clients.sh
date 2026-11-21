#!/usr/bin/env bash
# Sends one request per client certificate and shows what happened.
# Usage: ./scripts/test-clients.sh LB_IP HOSTNAME   (run from the lab folder)
set -u
IP="${1:?load balancer IP}"
HOST="${2:-mtls-lab.example.com}"
URL="https://${HOST}/"
# -k: the lab server certificate is self-signed. --resolve: no DNS record needed.
CURL=(curl -sS -k --max-time 15 --resolve "${HOST}:443:${IP}")

run() {
  local label="$1"; shift
  echo "=== ${label}"
  if out=$("${CURL[@]}" "$@" "$URL" 2>&1); then
    echo "$out"
  else
    echo "connection refused by the load balancer (curl: ${out##*curl: })"
  fi
  echo
}

run "no client certificate"
run "good client (leaf only; LB builds the chain from the intermediate)" --cert certs/good.crt --key certs/good.key
run "client certificate without EKU" --cert certs/noeku.crt --key certs/noeku.key
run "client certificate with serverAuth EKU only" --cert certs/serveronly.crt --key certs/serveronly.key
run "client from a rogue CA" --cert certs/rogue.crt --key certs/rogue.key
run "spoof attempt: no certificate, fake header" -H "X-Client-Cert-Present: true" -H "X-Client-Cert-Chain-Verified: true"
