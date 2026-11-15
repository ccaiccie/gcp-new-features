resource "google_compute_firewall_policy" "lab" {
  parent      = "folders/${var.folder_id}"
  short_name  = var.policy_short_name
  description = "Lab hierarchical policy: allow IAP SSH, deny SSH from the internet, then go to next."
}

# Higher priority (lower number) than the deny, so IAP still works.
resource "google_compute_firewall_policy_rule" "allow_iap_ssh" {
  firewall_policy = google_compute_firewall_policy.lab.id
  description     = "Allow SSH from Identity-Aware Proxy"
  priority        = 500
  action          = "allow"
  direction       = "INGRESS"
  enable_logging  = true

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22"]
    }
    src_ip_ranges = ["35.235.240.0/20"]
  }
}

resource "google_compute_firewall_policy_rule" "deny_internet_ssh" {
  firewall_policy = google_compute_firewall_policy.lab.id
  description     = "Deny SSH from the internet"
  priority        = 1000
  action          = "deny"
  direction       = "INGRESS"
  enable_logging  = true

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22"]
    }
    src_ip_ranges = ["0.0.0.0/0"]
  }
}

resource "google_compute_firewall_policy_association" "lab" {
  name              = "lab-folder-association"
  firewall_policy   = google_compute_firewall_policy.lab.id
  attachment_target = "folders/${var.folder_id}"
}
