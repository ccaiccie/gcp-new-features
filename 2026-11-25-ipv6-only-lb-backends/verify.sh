#!/usr/bin/env bash
set -euo pipefail

# Usage: ./verify.sh <PROJECT_ID> [REGION] [BACKEND_SERVICE_NAME]
PROJECT_ID="${1:?Provide GCP project ID}"
REGION="${2:-us-central1}"
BS_NAME="${3:-ipv6-lb-lab-bs}"

echo "=== 1. Inspect backend service ipAddressSelectionPolicy ==="
gcloud compute backend-services describe "${BS_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format="yaml(name,loadBalancingScheme,protocol,ipAddressSelectionPolicy)"

echo "=== 2. Check backend health (IPv6 health checks under IPV6_ONLY) ==="
gcloud compute backend-services get-health "${BS_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}"

echo "=== 3. Inspect dual-stack proxy-only subnet ==="
gcloud compute networks subnets describe "ipv6-lb-lab-proxy-only" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format="yaml(name,purpose,role,stackType,ipCidrRange,ipv6CidrRange)"

echo "=== 4. Test IPv4 and IPv6 frontends (replace with terraform output values) ==="
echo "curl -4 -i http://<FRONTEND_IPV4_ADDRESS>/"
echo "curl -6 -i http://[<FRONTEND_IPV6_ADDRESS_WITHOUT_PREFIX>]/"
