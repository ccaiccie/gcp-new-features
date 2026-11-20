output "cluster_name" {
  value = google_container_cluster.lab.name
}

output "location" {
  value = var.cluster_location
}

output "node_pool" {
  value = google_container_node_pool.pool.name
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.lab.name} --project=${var.project_id} --location=${var.cluster_location}"
}

output "datapath_status_command" {
  value = "gcloud container clusters describe ${google_container_cluster.lab.name} --project=${var.project_id} --location=${var.cluster_location} --format='value(networkConfig.datapathProvider)'"
}

output "env_for_scripts" {
  description = "Paste into your shell before running the scripts in scripts/."
  value       = "export PROJECT=${var.project_id} CLUSTER=${google_container_cluster.lab.name} LOCATION=${var.cluster_location} POOL=${google_container_node_pool.pool.name}"
}
