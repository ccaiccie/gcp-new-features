data "google_project" "lab" {
  project_id = var.project_id
}

locals {
  create_policy = var.existing_access_policy_id == ""
  policy_id     = local.create_policy ? google_access_context_manager_access_policy.scoped[0].name : var.existing_access_policy_id
  policy        = "accessPolicies/${local.policy_id}"
  project_res   = "projects/${data.google_project.lab.number}"
}

# ---------------------------------------------------------------------------
# 1. Access policy: a SCOPED policy for the lab project.
#    An organization can have only one organization-level policy, and this lab
#    does not touch it. Scoped policies are for VPC Service Controls; IAP cannot
#    use access levels from a scoped policy (it needs the org-level policy).
#    The scope cannot be changed after creation (delete and recreate instead).
# ---------------------------------------------------------------------------
resource "google_access_context_manager_access_policy" "scoped" {
  count  = local.create_policy ? 1 : 0
  parent = "organizations/${var.org_id}"
  title  = "${var.name_prefix}_scoped_policy"
  scopes = [local.project_res]
}

# ---------------------------------------------------------------------------
# 2. Basic access levels
# ---------------------------------------------------------------------------

# Office egress ranges. Several CIDRs in one condition are ORed with each other.
resource "google_access_context_manager_access_level" "corp_network" {
  parent = local.policy
  name   = "${local.policy}/accessLevels/${var.name_prefix}_corp_network"
  title  = "${var.name_prefix}_corp_network"
  basic {
    conditions {
      ip_subnetworks = var.corp_cidrs
    }
  }
}

# Countries, from the geolocation of the PUBLIC source IP.
resource "google_access_context_manager_access_level" "allowed_regions" {
  parent = local.policy
  name   = "${local.policy}/accessLevels/${var.name_prefix}_allowed_regions"
  title  = "${var.name_prefix}_allowed_regions"
  basic {
    conditions {
      regions = var.allowed_regions
    }
  }
}

# Nesting: both levels must be granted (attributes within one condition are ANDed).
resource "google_access_context_manager_access_level" "corp_and_region" {
  parent = local.policy
  name   = "${local.policy}/accessLevels/${var.name_prefix}_corp_and_region"
  title  = "${var.name_prefix}_corp_and_region"
  basic {
    combining_function = "AND"
    conditions {
      required_access_levels = [
        google_access_context_manager_access_level.corp_network.name,
        google_access_context_manager_access_level.allowed_regions.name,
      ]
    }
  }
}

# Optional device level. Needs Endpoint Verification and a paid subscription to be MET.
resource "google_access_context_manager_access_level" "managed_device" {
  count  = var.enable_device_level ? 1 : 0
  parent = local.policy
  name   = "${local.policy}/accessLevels/${var.name_prefix}_managed_device"
  title  = "${var.name_prefix}_managed_device"
  basic {
    conditions {
      device_policy {
        require_screen_lock         = true
        require_corp_owned          = true
        allowed_encryption_statuses = ["ENCRYPTED"]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 3. Custom access level (CEL): office range AND an allowed country AND
#    07:00-19:00 in the chosen time zone. Uses inIpRange() rather than string
#    comparison, as the docs recommend. Not used by the perimeter; attach it to
#    an ingress rule yourself as an experiment.
# ---------------------------------------------------------------------------
resource "google_access_context_manager_access_level" "office_hours" {
  parent = local.policy
  name   = "${local.policy}/accessLevels/${var.name_prefix}_office_hours"
  title  = "${var.name_prefix}_office_hours"
  custom {
    expr {
      title       = "Office range, allowed country, 07:00-19:00"
      description = "Example custom level for the Access Context Manager lesson."
      expression = join(" && ", [
        "inIpRange(origin.ip, ${jsonencode(var.corp_cidrs)})",
        "origin.region_code in ${jsonencode(var.allowed_regions)}",
        "request.time.getHours(\"${var.business_hours_tz}\") >= 7",
        "request.time.getHours(\"${var.business_hours_tz}\") < 19",
      ])
    }
  }
}

# ---------------------------------------------------------------------------
# 4. Something to protect
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "test" {
  count                       = var.create_test_bucket ? 1 : 0
  name                        = "${replace(lower(var.name_prefix), "_", "-")}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# ---------------------------------------------------------------------------
# 5. Service perimeter in DRY-RUN only.
#    There is no status {} block, so NOTHING is enforced. The proposed config
#    lives in spec {} with use_explicit_dry_run_spec = true; requests that would
#    be denied appear in the audit logs as dry-run violations.
# ---------------------------------------------------------------------------
resource "google_access_context_manager_service_perimeter" "lab" {
  parent = local.policy
  name   = "${local.policy}/servicePerimeters/${var.name_prefix}_perimeter"
  title  = "${var.name_prefix}_perimeter"

  use_explicit_dry_run_spec = true
  spec {
    resources           = [local.project_res]
    restricted_services = ["storage.googleapis.com"]

    # Broad way in (not used here): access_levels = [ ... ] lets ANY identity that
    # meets the level reach EVERY restricted service in the perimeter.
    # Precise way in: the access level as the ingress SOURCE, limited identities,
    # one service.
    ingress_policies {
      title = "office-to-storage"
      ingress_from {
        identity_type = length(var.ingress_identities) == 0 ? "ANY_IDENTITY" : null
        identities    = length(var.ingress_identities) == 0 ? null : var.ingress_identities
        sources {
          access_level = google_access_context_manager_access_level.corp_and_region.name
        }
      }
      ingress_to {
        resources = ["*"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors {
            method = "*"
          }
        }
      }
    }
  }
}
