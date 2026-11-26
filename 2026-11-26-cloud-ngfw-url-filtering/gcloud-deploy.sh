#!/usr/bin/env bash
set -euo pipefail

# Replace with your own Google Cloud project ID before running.
PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
PREFIX="${PREFIX:-urlf-lab}"

gcloud config set project "${PROJECT_ID}"

# 1. Enable required APIs
gcloud services enable compute.googleapis.com networksecurity.googleapis.com iap.googleapis.com

# 2. Create custom VPC (1460 MTU) and subnet
gcloud compute networks create "${PREFIX}-vpc" \
  --subnet-mode=custom \
  --mtu=1460

gcloud compute networks subnets create "${PREFIX}-subnet" \
  --network="${PREFIX}-vpc" \
  --region="${REGION}" \
  --range=10.10.0.0/24 \
  --enable-private-ip-google-access

# 3. Create Cloud Router and Cloud NAT for private VM egress
gcloud compute routers create "${PREFIX}-router" \
  --network="${PREFIX}-vpc" \
  --region="${REGION}"

gcloud compute routers nats create "${PREFIX}-nat" \
  --router="${PREFIX}-router" \
  --region="${REGION}" \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges

# 4. Create private test VM without a public IP
gcloud compute instances create "${PREFIX}-client" \
  --zone="${ZONE}" \
  --machine-type=e2-micro \
  --network-interface="stack-type=IPV4_ONLY,subnet=${PREFIX}-subnet,no-address" \
  --image-project=debian-cloud \
  --image-family=debian-12

# 5. Import project-level URL filtering security profile
gcloud network-security security-profiles import "${PREFIX}-urlf-profile" \
  --source=url-filtering-profile.yaml \
  --project="${PROJECT_ID}" \
  --location=global

# 6. Create project-level security profile group
gcloud network-security security-profile-groups create "${PREFIX}-urlf-spg" \
  --project="${PROJECT_ID}" \
  --location=global \
  --url-filtering-profile="projects/${PROJECT_ID}/locations/global/securityProfiles/${PREFIX}-urlf-profile" \
  --description="Security profile group for Cloud NGFW URL filtering"

# 7. Create zonal firewall endpoint and associate it with the VPC
gcloud network-security firewall-endpoints create "${PREFIX}-endpoint" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --billing-project="${PROJECT_ID}"

gcloud network-security firewall-endpoint-associations create "${PREFIX}-endpoint-assoc" \
  --endpoint="projects/${PROJECT_ID}/locations/${ZONE}/firewallEndpoints/${PREFIX}-endpoint" \
  --network="${PREFIX}-vpc" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

# 8. Create global network firewall policy, IAP SSH rule, and L7 egress rule
gcloud compute network-firewall-policies create "${PREFIX}-fw-policy" \
  --global \
  --project="${PROJECT_ID}"

gcloud compute network-firewall-policies rules create 100 \
  --firewall-policy="${PREFIX}-fw-policy" \
  --direction=INGRESS \
  --action=ALLOW \
  --src-ip-ranges=35.235.240.0/20 \
  --layer4-configs=tcp:22 \
  --global-firewall-policy \
  --enable-logging

gcloud compute network-firewall-policies rules create 200 \
  --firewall-policy="${PREFIX}-fw-policy" \
  --direction=EGRESS \
  --action=apply_security_profile_group \
  --dest-ip-ranges=0.0.0.0/0 \
  --layer4-configs=tcp:80,tcp:443 \
  --global-firewall-policy \
  --security-profile-group="//networksecurity.googleapis.com/projects/${PROJECT_ID}/locations/global/securityProfileGroups/${PREFIX}-urlf-spg" \
  --enable-logging

gcloud compute network-firewall-policies associations create \
  --firewall-policy="${PREFIX}-fw-policy" \
  --network="${PREFIX}-vpc" \
  --name="${PREFIX}-fw-policy-assoc" \
  --global-firewall-policy \
  --project="${PROJECT_ID}"

echo "Lab deployed. Wait until the firewall endpoint and association reach ACTIVE state before testing."
