#!/usr/bin/env bash
# Shows the lab's Unified Access Policy and the bindings that apply to the project.
# Usage: ./scripts/inspect-uap.sh PROJECT_ID [POLICY_ID]
set -euo pipefail
P="${1:?project}"; POLICY="${2:-uap-network-guardrail}"
echo "--- access policies in the project"
gcloud iam access-policies list --project="$P" --location=global
echo "--- the lab policy (rules as JSON)"
gcloud iam access-policies describe "$POLICY" --project="$P" --location=global --format=json
echo "--- policy bindings parented by the project"
gcloud iam policy-bindings list --project="$P" --location=global
