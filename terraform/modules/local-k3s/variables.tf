variable "cluster_name"           { type = string; default = "data-platform" }
variable "proxmox_api_url"        { type = string }
variable "proxmox_user"           { type = string; default = "root@pam" }
variable "proxmox_password"       { type = string; sensitive = true }
variable "proxmox_node"           { type = string }
variable "vm_template"            { type = string; description = "Proxmox template name (Ubuntu 22.04 recommended)" }
variable "storage_pool"           { type = string; default = "local-lvm" }
variable "vm_user"                { type = string; default = "ubuntu" }
variable "ssh_private_key_path"   { type = string; default = "~/.ssh/id_rsa" }
variable "data_node_count"        { type = number; default = 3 }
