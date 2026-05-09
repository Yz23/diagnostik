variable "cluster_name" {
  type    = string
  default = "data-platform"
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_user" {
  type = string
  # FIX B9 : Ne pas utiliser root@pam en production.
  # Créer un compte de service dédié avec des permissions minimales :
  #   pveum user add terraform@pve
  #   pveum aclmod / -user terraform@pve -role PVEVMAdmin
  #   pveum aclmod /storage -user terraform@pve -role PVEDatastoreAdmin
  # Ou utiliser un token API :
  #   pveum user tokenadd terraform@pve terraform --privsep 0
  description = "Proxmox user (ex: terraform@pve — éviter root@pam)"
  default     = "terraform@pve"
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "vm_template" {
  type        = string
  description = "Proxmox template name (Ubuntu 22.04 recommended)"
}

variable "storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "vm_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "data_node_count" {
  type    = number
  default = 3
}
