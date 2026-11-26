#!/usr/bin/env bash
# =============================================================================
# Google Cloud Private Service Connect (Producer -> Consumer) gcloud Lab
# Replace placeholder project IDs before running.
# Official docs:
#   https://cloud.google.com/vpc/docs/configure-private-service-connect-producer
#   https://cloud.google.com/vpc/docs/configure-private-service-connect-services
# =============================================================================

set -euo pipefail

export PRODUCER_PROJECT="my-producer-project-id"
export CONSUMER_PROJECT="my-consumer-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"

# -----------------------------------------------------------------------------
# 1. PRODUCER: VPC, Backend Subnet, Dedicated PSC NAT Subnet
# -----------------------------------------------------------------------------
gcloud compute networks create psc-producer-vpc \
  --project="$PRODUCER_PROJECT" \
  --subnet-mode=custom

gcloud compute networks subnets create psc-producer-backend-subnet \
  --project="$PRODUCER_PROJECT" \
  --network=psc-producer-vpc \
  --region="$REGION" \
  --range=10.10.1.0/24

gcloud compute networks subnets create psc-producer-nat-subnet \
  --project="$PRODUCER_PROJECT" \
  --network=psc-producer-vpc \
  --region="$REGION" \
  --range=10.10.2.0/28 \
  --purpose=PRIVATE_SERVICE_CONNECT

# Firewall rules: health checks + SNATed consumer traffic from PSC NAT subnet
gcloud compute firewall-rules create psc-producer-allow-hc \
  --project="$PRODUCER_PROJECT" \
  --network=psc-producer-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=35.191.0.0/16,130.211.0.0/22 \
  --target-tags=psc-backend

gcloud compute firewall-rules create psc-producer-allow-psc-nat \
  --project="$PRODUCER_PROJECT" \
  --network=psc-producer-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=10.10.2.0/28 \
  --target-tags=psc-backend

# Producer backend VM + Internal Passthrough Network Load Balancer
gcloud compute instances create psc-producer-backend-1 \
  --project="$PRODUCER_PROJECT" \
  --zone="$ZONE" \
  --subnet=psc-producer-backend-subnet \
  --no-address \
  --machine-type=e2-micro \
  --tags=psc-backend \
  --metadata=startup-script='#! /bin/bash
    apt-get update -y && apt-get install -y python3
    python3 -m http.server 80 &'

gcloud compute instance-groups unmanaged create psc-producer-ig \
  --project="$PRODUCER_PROJECT" \
  --zone="$ZONE"

gcloud compute instance-groups unmanaged add-instances psc-producer-ig \
  --project="$PRODUCER_PROJECT" \
  --zone="$ZONE" \
  --instances=psc-producer-backend-1

gcloud compute health-checks create tcp psc-producer-hc \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --port=80

gcloud compute backend-services create psc-producer-ilb-backend \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --load-balancing-scheme=INTERNAL \
  --protocol=TCP \
  --health-checks=psc-producer-hc \
  --health-checks-region="$REGION"

gcloud compute backend-services add-backend psc-producer-ilb-backend \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --instance-group=psc-producer-ig \
  --instance-group-zone="$ZONE"

gcloud compute forwarding-rules create psc-producer-ilb-fr \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --load-balancing-scheme=INTERNAL \
  --network=psc-producer-vpc \
  --subnet=psc-producer-backend-subnet \
  --ip-protocol=TCP \
  --ports=80 \
  --backend-service=psc-producer-ilb-backend \
  --backend-service-region="$REGION"

# -----------------------------------------------------------------------------
# 2. PRODUCER: Publish Service Attachment (Explicit Approval + Reconcile)
# -----------------------------------------------------------------------------
gcloud compute service-attachments create psc-producer-sa \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --target-service=psc-producer-ilb-fr \
  --connection-preference=ACCEPT_MANUAL \
  --nat-subnets=psc-producer-nat-subnet \
  --consumer-accept-list="${CONSUMER_PROJECT}=2" \
  --domain-names="us-central1.p.example.internal." \
  --reconcile-connections

export SA_URI="projects/${PRODUCER_PROJECT}/regions/${REGION}/serviceAttachments/psc-producer-sa"

# -----------------------------------------------------------------------------
# 3. CONSUMER: VPC (Same 10.10.1.0/24 CIDR!), Static IP, PSC Endpoint, Private DNS
# -----------------------------------------------------------------------------
gcloud compute networks create psc-consumer-vpc \
  --project="$CONSUMER_PROJECT" \
  --subnet-mode=custom

gcloud compute networks subnets create psc-consumer-subnet \
  --project="$CONSUMER_PROJECT" \
  --network=psc-consumer-vpc \
  --region="$REGION" \
  --range=10.10.1.0/24

gcloud compute addresses create psc-consumer-endpoint-ip \
  --project="$CONSUMER_PROJECT" \
  --region="$REGION" \
  --subnet=psc-consumer-subnet \
  --addresses=10.10.1.50

gcloud compute forwarding-rules create psc-consumer-endpoint \
  --project="$CONSUMER_PROJECT" \
  --region="$REGION" \
  --network=psc-consumer-vpc \
  --address=psc-consumer-endpoint-ip \
  --target-service-attachment="$SA_URI"

# Manual Private Cloud DNS zone + A record
gcloud dns managed-zones create psc-lab-private-zone \
  --project="$CONSUMER_PROJECT" \
  --dns-name="psc-lab.internal." \
  --description="Private zone for PSC published service" \
  --visibility=private \
  --networks=psc-consumer-vpc

gcloud dns record-sets create app.psc-lab.internal. \
  --project="$CONSUMER_PROJECT" \
  --zone=psc-lab-private-zone \
  --type=A \
  --ttl=300 \
  --rrdatas=10.10.1.50

# -----------------------------------------------------------------------------
# 4. VERIFICATION & ACCESS CONTROL DEMO
# -----------------------------------------------------------------------------
gcloud compute service-attachments describe psc-producer-sa \
  --project="$PRODUCER_PROJECT" \
  --region="$REGION" \
  --show-nat-ips

gcloud compute forwarding-rules describe psc-consumer-endpoint \
  --project="$CONSUMER_PROJECT" \
  --region="$REGION" \
  --format="yaml(IPAddress,pscConnectionId,pscConnectionStatus,target)"

# Optional: Demonstrate REJECTED status by moving consumer to reject list
# gcloud compute service-attachments update psc-producer-sa \
#   --project="$PRODUCER_PROJECT" \
#   --region="$REGION" \
#   --consumer-accept-list="" \
#   --consumer-reject-list="$CONSUMER_PROJECT"

# -----------------------------------------------------------------------------
# 5. CLEAN TEAR-DOWN ORDER (CONSUMER FIRST, THEN PRODUCER)
# -----------------------------------------------------------------------------
# 1. Consumer DNS records & zone, test VM, PSC forwarding rule, static IP, subnet, VPC
# 2. Producer service attachment, ILB forwarding rule, backend service, health check,
#    instance group, backend VM, firewall rules, NAT subnet, backend subnet, VPC
