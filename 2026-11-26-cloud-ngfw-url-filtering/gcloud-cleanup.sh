#!/usr/bin/env bash
set -euo pipefail

# Tears down all resources created by gcloud-deploy.sh so charges stop.
PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
PREFIX="${PREFIX:-urlf-lab}"

gcloud config set project "${PROJECT_ID}"

gcloud compute network-firewall-policies associations delete \
  --name="${PREFIX}-fw-policy-assoc" \
  --firewall-policy="${PREFIX}-fw-policy" \
  --global-firewall-policy --quiet || true

gcloud compute network-firewall-policies delete "${PREFIX}-fw-policy" --global --quiet || true

gcloud network-security firewall-endpoint-associations delete "${PREFIX}-endpoint-assoc" \
  --zone="${ZONE}" --project="${PROJECT_ID}" --quiet || true

gcloud network-security firewall-endpoints delete "${PREFIX}-endpoint" \
  --zone="${ZONE}" --project="${PROJECT_ID}" --quiet || true

gcloud network-security security-profile-groups delete "${PREFIX}-urlf-spg" \
  --project="${PROJECT_ID}" --location=global --quiet || true

gcloud network-security security-profiles url-filtering delete "${PREFIX}-urlf-profile" \
  --project="${PROJECT_ID}" --location=global --quiet || true

gcloud compute instances delete "${PREFIX}-client" --zone="${ZONE}" --quiet || true
gcloud compute routers nats delete "${PREFIX}-nat" --router="${PREFIX}-router" --region="${REGION}" --quiet || true
gcloud compute routers delete "${PREFIX}-router" --region="${REGION}" --quiet || true
gcloud compute networks subnets delete "${PREFIX}-subnet" --region="${REGION}" --quiet || true
gcloud compute networks delete "${PREFIX}-vpc" --quiet || true

echo "Cleanup complete."
