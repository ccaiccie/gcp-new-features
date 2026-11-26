name: authz-lab-deny-by-default
target:
  loadBalancingScheme: INTERNAL_MANAGED
  resources:
    - "https://www.googleapis.com/compute/v1/projects/PROJECT_ID/regions/REGION/forwardingRules/FORWARDING_RULE_NAME"
action: DENY_BY_DEFAULT
