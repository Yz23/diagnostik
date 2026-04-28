# ── Local / Proxmox deployment ─────────────────────────────────
# export PM_API_URL=https://192.168.1.100:8006/api2/json
# export PM_USER=root@pam && export PM_PASS=yourpassword
# terraform -chdir=../modules/local-k3s apply -var-file=../../terraform/environments/example-local.tfvars

cluster_name         = "data-platform"
proxmox_api_url      = "https://192.168.1.100:8006/api2/json"
proxmox_user         = "root@pam"
proxmox_node         = "pve"
vm_template          = "ubuntu-22.04-template"
storage_pool         = "local-lvm"
vm_user              = "ubuntu"
ssh_private_key_path = "~/.ssh/id_rsa"
data_node_count      = 3
