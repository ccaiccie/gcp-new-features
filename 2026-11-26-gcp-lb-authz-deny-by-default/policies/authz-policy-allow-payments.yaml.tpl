name: authz-lab-allow-payments
target:
  loadBalancingScheme: INTERNAL_MANAGED
  resources:
    - "https://www.googleapis.com/compute/v1/projects/PROJECT_ID/regions/REGION/forwardingRules/FORWARDING_RULE_NAME"
httpRules:
  - from:
      sources:
        - resources:
            - iamServiceAccount:
                exact: "CLIENT_SA_EMAIL"
    to:
      operations:
        - paths:
            - exact: "/api/payments"
action: ALLOW
