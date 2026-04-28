# ── Azure deployment ───────────────────────────────────────────
# az login
# terraform -chdir=../modules/azure-aks apply -var-file=../../terraform/environments/example-azure.tfvars

cluster_name       = "data-platform"
location           = "westeurope"
general_node_count = 2
data_node_count    = 3
general_vm_size    = "Standard_D4s_v3"
data_vm_size       = "Standard_E8s_v3"
