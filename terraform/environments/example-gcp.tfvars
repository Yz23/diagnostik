# ── GCP deployment ─────────────────────────────────────────────
# terraform -chdir=../modules/gcp-gke init
# terraform -chdir=../modules/gcp-gke apply -var-file=../../terraform/environments/example-gcp.tfvars

project_id           = "infrastructure-resiliente"
region               = "europe-west1"
cluster_name         = "data-platform"
general_node_count   = 2
data_node_count      = 3
general_machine_type = "e2-standard-4"
data_machine_type    = "n2-highmem-8"
