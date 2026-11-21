data "google_project" "this" {
  project_id = var.project_id
}

locals {
  apis = [
    "iam.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
  netops_principal     = "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.netops.email}"
  breakglass_principal = "principal://iam.googleapis.com/projects/-/serviceAccounts/${google_service_account.breakglass.email}"
  # Every service account created in this project (service agents are separate principal sets)
  all_project_sas = "principalSet://cloudresourcemanager.googleapis.com/projects/${data.google_project.this.number}/type/ServiceAccount"
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------- identities ----------
resource "google_service_account" "netops" {
  account_id   = "${var.name_prefix}-netops"
  display_name = "UAP lab: network automation identity"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "breakglass" {
  account_id   = "${var.name_prefix}-breakglass"
  display_name = "UAP lab: break-glass identity"
  depends_on   = [google_project_service.apis]
}

# Let the tester impersonate both identities for the gcloud tests
resource "google_service_account_iam_member" "tester_netops" {
  service_account_id = google_service_account.netops.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.tester_member
}

resource "google_service_account_iam_member" "tester_breakglass" {
  service_account_id = google_service_account.breakglass.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.tester_member
}

# ---------- classic allow policy (the "old" model, still evaluated) ----------
# Both identities get Compute Security Admin, which includes firewall create and delete.
resource "google_project_iam_member" "secadmin" {
  for_each = {
    netops     = google_service_account.netops.member
    breakglass = google_service_account.breakglass.member
  }
  project = var.project_id
  role    = "roles/compute.securityAdmin"
  member  = each.value
}

# A VPC the tests can attach firewall rules to
resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-lab-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

# ---------- Unified Access Policy: allow + deny rules in one policy ----------
resource "google_iam_project_access_policy" "network_guardrail" {
  project          = var.project_id
  location         = "global"
  access_policy_id = "${var.name_prefix}-network-guardrail"
  display_name     = "Network guardrail (lab)"

  details {
    # Rule 1: ALLOW. A predefined role, granted by the UAP, not by the allow policy.
    rules {
      description = "netops can view network configuration"
      effect      = "ALLOW"
      principals  = [local.netops_principal]
      operation {
        permissions = ["role:roles/compute.networkViewer"]
      }
    }

    # Rule 2: DENY. A permission group with an exception principal and excluded permissions.
    rules {
      description         = "Only break-glass may change firewall rules"
      effect              = "DENY"
      principals          = [local.all_project_sas]
      excluded_principals = [local.breakglass_principal]
      operation {
        permissions = ["compute.googleapis.com/firewalls.*"]
        # Reading stays possible; only changes are denied
        excluded_permissions = [
          "compute.googleapis.com/firewalls.get",
          "compute.googleapis.com/firewalls.list",
        ]
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# A UAP has no effect until it is bound. Project-level policies bind to their own project.
resource "google_iam_projects_policy_binding" "network_guardrail" {
  project           = var.project_id
  location          = "global"
  policy_binding_id = "${var.name_prefix}-network-guardrail-binding"
  display_name      = "Network guardrail on this project"
  policy_kind       = "ACCESS"
  policy            = google_iam_project_access_policy.network_guardrail.name

  target {
    resource = "//cloudresourcemanager.googleapis.com/projects/${var.project_id}"
  }
}
