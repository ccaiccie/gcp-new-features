data "google_project" "service" {
  provider   = google.service
  project_id = var.service_project_id
}

resource "google_project_service" "host_compute" {
  provider           = google.host
  project            = var.host_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "service_compute" {
  provider           = google.service
  project            = var.service_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  provider = google.host
  project  = var.host_project_id

  depends_on = [google_project_service.host_compute]
}

resource "google_compute_network" "shared" {
  provider                = google.host
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_project_service.host_compute]
}

resource "google_compute_subnetwork" "tier1" {
  provider      = google.host
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.shared.id
  stack_type    = "IPV4_ONLY"

  secondary_ip_range {
    range_name    = "${var.subnet_name}-pods"
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = "${var.subnet_name}-services"
    ip_cidr_range = var.services_secondary_cidr
  }
}

resource "google_compute_shared_vpc_service_project" "service" {
  provider        = google.host
  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = var.service_project_id
}

resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = toset(concat(
    var.network_user_members,
    [
      "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com",
      "serviceAccount:${data.google_project.service.number}-compute@developer.iam.gserviceaccount.com",
    ]
  ))

  provider   = google.host
  project    = var.host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.tier1.name
  role       = "roles/compute.networkUser"
  member     = each.value

  depends_on = [google_compute_shared_vpc_service_project.service]
}

# Allow IAP TCP forwarding to the sample VM, and internal traffic in the subnet.
resource "google_compute_firewall" "allow_iap_ssh" {
  provider = google.host
  name     = "allow-iap-ssh"
  network  = google_compute_network.shared.name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]
}

resource "google_compute_firewall" "allow_internal" {
  provider = google.host
  name     = "allow-internal"
  network  = google_compute_network.shared.name

  direction = "INGRESS"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  source_ranges = [var.subnet_cidr]
}

resource "google_compute_instance" "sample" {
  provider     = google.service
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.tier1.self_link
    subnetwork_project = var.host_project_id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [
    google_compute_shared_vpc_service_project.service,
    google_compute_subnetwork_iam_member.network_user,
    google_project_service.service_compute,
  ]
}
