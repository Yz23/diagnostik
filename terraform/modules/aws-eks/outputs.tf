output "kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
}

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}
