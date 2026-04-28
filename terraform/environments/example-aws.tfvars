# ── AWS deployment ─────────────────────────────────────────────
# export AWS_ACCESS_KEY_ID=...
# export AWS_SECRET_ACCESS_KEY=...
# terraform -chdir=../modules/aws-eks apply -var-file=../../terraform/environments/example-aws.tfvars

cluster_name          = "data-platform"
region                = "eu-west-1"
general_node_count    = 2
data_node_count       = 3
general_instance_type = "m6i.xlarge"
data_instance_type    = "r6i.2xlarge"
