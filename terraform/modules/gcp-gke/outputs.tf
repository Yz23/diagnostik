output "kubeconfig_cmd" {
  value = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}
output "cluster_endpoint" {
  value     = google_container_cluster.primary.endpoint
  sensitive = true
}
