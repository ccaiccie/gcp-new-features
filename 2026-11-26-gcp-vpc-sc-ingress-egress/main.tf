# SAFETY WARNING:
# Run ONLY in a disposable test organization and disposable test projects.
# VPC Service Controls is an organization-level control. An enforced perimeter
# can block access to Google Cloud services until it is removed.

locals {
  restricted_services = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
  ]
}

resource "google_storage_bucket" "protected_demo_bucket" {
  name                        = "${var.protected_project_id}-vpcsc-lab-bucket"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_access_context_manager_service_perimeter" "lab_perimeter" {
  parent         = "accessPolicies/${var.access_policy_id}"
  name           = "accessPolicies/${var.access_policy_id}/servicePerimeters/${var.perimeter_name}"
  title          = var.perimeter_name
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  # Dry-run configuration is always explicitly managed in spec.
  use_explicit_dry_run_spec = true

  spec {
    resources           = ["projects/${var.protected_project_number}"]
    restricted_services = local.restricted_services

    # Ingress rule: allow the lab operator from any network origin to access
    # Cloud Storage and BigQuery inside the protected disposable project.
    ingress_policies {
      title = "allow_operator_ingress_gcs_bq"
      ingress_from {
        identities = [var.operator_identity]
        sources {
          access_level = "*"
        }
      }
      ingress_to {
        resources = ["projects/${var.protected_project_number}"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors {
            method = "*"
          }
        }
        operations {
          service_name = "bigquery.googleapis.com"
          method_selectors {
            method = "*"
          }
        }
      }
    }

    # Egress rule: allow identities inside the perimeter to read objects from
    # a specific external disposable project (for example, BigQuery loading from GCS).
    egress_policies {
      title = "allow_egress_to_external_gcs_project"
      egress_from {
        identities = [var.operator_identity]
      }
      egress_to {
        resources = ["projects/${var.external_project_number}"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors {
            permission = "storage.objects.get"
          }
          method_selectors {
            permission = "storage.objects.list"
          }
        }
      }
    }
  }

  # Enforced configuration is empty while enforce_perimeter = false.
  # Flip enforce_perimeter = true only after dry-run audit logs look clean.
  dynamic "status" {
    for_each = var.enforce_perimeter ? [1] : []
    content {
      resources           = ["projects/${var.protected_project_number}"]
      restricted_services = local.restricted_services

      ingress_policies {
        title = "allow_operator_ingress_gcs_bq"
        ingress_from {
          identities = [var.operator_identity]
          sources {
            access_level = "*"
          }
        }
        ingress_to {
          resources = ["projects/${var.protected_project_number}"]
          operations {
            service_name = "storage.googleapis.com"
            method_selectors {
              method = "*"
            }
          }
          operations {
            service_name = "bigquery.googleapis.com"
            method_selectors {
              method = "*"
            }
          }
        }
      }

      egress_policies {
        title = "allow_egress_to_external_gcs_project"
        egress_from {
          identities = [var.operator_identity]
        }
        egress_to {
          resources = ["projects/${var.external_project_number}"]
          operations {
            service_name = "storage.googleapis.com"
            method_selectors {
              permission = "storage.objects.get"
            }
            method_selectors {
              permission = "storage.objects.list"
            }
          }
        }
      }
    }
  }
}
