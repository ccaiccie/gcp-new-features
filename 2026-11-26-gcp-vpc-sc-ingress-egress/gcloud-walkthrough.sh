#!/usr/bin/env bash
# SAFETY WARNING:
# Run ONLY in a disposable test organization and disposable test projects.
# VPC Service Controls is an organization-level control. An enforced perimeter
# can block access to Google Cloud services until it is removed.

set -euo pipefail

POLICY_ID="123456789012"
PERIMETER_NAME="lab_vpc_sc_demo_perimeter"
PROTECTED_PROJECT_NUM="111111111111"
PROTECTED_PROJECT_ID="your-disposable-protected-project"
PROTECTED_BUCKET="${PROTECTED_PROJECT_ID}-vpcsc-lab-bucket"

echo "=== Step 1: Create dry-run perimeter with NO ingress or egress rules ==="
gcloud access-context-manager perimeters dry-run create "${PERIMETER_NAME}" \
  --perimeter-title="Lab VPC-SC Demo Perimeter" \
  --perimeter-type="regular" \
  --perimeter-resources="projects/${PROTECTED_PROJECT_NUM}" \
  --perimeter-restricted-services="storage.googleapis.com,bigquery.googleapis.com" \
  --policy="${POLICY_ID}"

echo "=== Step 2: Inspect dry-run audit logs after exercising GCS/BigQuery ==="
gcloud logging read \
  'log_id("cloudaudit.googleapis.com/policy") AND severity="error" AND protoPayload.metadata.dryRun="true"' \
  --project="${PROTECTED_PROJECT_ID}" \
  --limit=20

echo "=== Step 3: Add ingress and egress rules to dry-run configuration ==="
gcloud access-context-manager perimeters dry-run update "${PERIMETER_NAME}" \
  --set-ingress-policies=ingress.yaml \
  --set-egress-policies=egress.yaml \
  --policy="${POLICY_ID}"

echo "=== Step 4: Enforce the modified dry-run configuration ==="
echo "Note: Propagation can take up to 30 minutes; temporary 403 errors may occur."
gcloud access-context-manager perimeters dry-run enforce "${PERIMETER_NAME}" \
  --policy="${POLICY_ID}"

echo "=== Step 5: Trigger a denied request (using an identity NOT in ingress.yaml) ==="
echo "Run gcloud storage ls gs://${PROTECTED_BUCKET} as a second test identity to get a denial + unique ID."

echo "=== Step 6: Teardown — remove the perimeter cleanly ==="
echo "Uncomment the command below when finished so no enforced rules remain:"
echo "# gcloud access-context-manager perimeters delete ${PERIMETER_NAME} --policy=${POLICY_ID}"
