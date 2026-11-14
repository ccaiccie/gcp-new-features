output "cluster_name" {
  value = var.create_cluster ? google_container_cluster.lab[0].name : null
}

output "cluster_endpoint" {
  value     = var.create_cluster ? google_container_cluster.lab[0].endpoint : null
  sensitive = true
}

output "membership_id" {
  value = var.create_cluster ? google_gke_hub_membership.lab[0].membership_id : null
}

output "mesh_feature" {
  value = google_gke_hub_feature.mesh.name
}

output "mesh_management" {
  value = var.create_cluster ? google_gke_hub_feature_membership.mesh[0].mesh[0].management : null
}
