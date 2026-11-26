#!/usr/bin/env bash
# Equivalent gcloud CLI workflow for Cloud NGFW protecting managed Envoy proxies
# (Internal Application Load Balancer & Internal Proxy Network Load Balancer).
# Replace the placeholder variables with your own values before running.

set -euo pipefail

PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
VPC_NAME="ngfw-ilb-lab-vpc"
POLICY_NAME="ngfw-ilb-lab-policy"
FORWARDING_RULE_NAME="ngfw-ilb-lab-alb-fr"
APPROVED_CLIENT_IP="10.128.20.2"

FORWARDING_RULE_REF="projects/${PROJECT_ID}/regions/${REGION}/forwardingRules/${FORWARDING_RULE_NAME}"

# 1. Create a Regional Network Firewall Policy
gcloud compute network-firewall-policies create "${POLICY_NAME}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --description="Protect managed Envoy proxies for internal ALB and proxy NLB"

# 2. Associate the policy with the VPC network
gcloud compute network-firewall-policies associations create \
  --project="${PROJECT_ID}" \
  --firewall-policy="${POLICY_NAME}" \
  --firewall-policy-region="${REGION}" \
  --network="${VPC_NAME}" \
  --name="${POLICY_NAME}-assoc"

# 3. Priority 900: Allow Google managed Envoy frontend health-check probes (IPv4)
gcloud compute network-firewall-policies rules create 900 \
  --project="${PROJECT_ID}" \
  --firewall-policy="${POLICY_NAME}" \
  --firewall-policy-region="${REGION}" \
  --direction=INGRESS \
  --action=allow \
  --target-type=INTERNAL_MANAGED_LB \
  --target-forwarding-rules="${FORWARDING_RULE_REF}" \
  --src-ip-ranges="35.191.0.0/16" \
  --layer4-configs="tcp" \
  --enable-logging

# 4. Priority 1000: Allow approved client IP
gcloud compute network-firewall-policies rules create 1000 \
  --project="${PROJECT_ID}" \
  --firewall-policy="${POLICY_NAME}" \
  --firewall-policy-region="${REGION}" \
  --direction=INGRESS \
  --action=allow \
  --target-type=INTERNAL_MANAGED_LB \
  --target-forwarding-rules="${FORWARDING_RULE_REF}" \
  --src-ip-ranges="${APPROVED_CLIENT_IP}/32" \
  --layer4-configs="tcp" \
  --enable-logging

# 5. Priority 2000: Baseline DENY all other ingress (Envoy proxies default to ALLOW)
# Tip: Omit --target-forwarding-rules on rules 900/1000/2000 to protect ALL internal
# ALB and internal proxy NLB forwarding rules in the associated VPC network.
gcloud compute network-firewall-policies rules create 2000 \
  --project="${PROJECT_ID}" \
  --firewall-policy="${POLICY_NAME}" \
  --firewall-policy-region="${REGION}" \
  --direction=INGRESS \
  --action=deny \
  --target-type=INTERNAL_MANAGED_LB \
  --target-forwarding-rules="${FORWARDING_RULE_REF}" \
  --src-ip-ranges="0.0.0.0/0" \
  --layer4-configs="tcp" \
  --enable-logging

# --- Global Network Firewall Policy Equivalent ---
# Replace --region="${REGION}" / --firewall-policy-region="${REGION}" with --global / --global-firewall-policy.
# For cross-region internal ALB or cross-region internal proxy NLB forwarding rules, use:
#   projects/${PROJECT_ID}/global/forwardingRules/${FORWARDING_RULE_NAME}

# --- Cleanup Commands (Manual teardown order) ---
# gcloud compute network-firewall-policies associations delete --name="${POLICY_NAME}-assoc" --firewall-policy="${POLICY_NAME}" --firewall-policy-region="${REGION}" --project="${PROJECT_ID}"
# gcloud compute network-firewall-policies delete "${POLICY_NAME}" --region="${REGION}" --project="${PROJECT_ID}"
