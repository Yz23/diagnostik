terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
  # Remote state : bash scripts/bootstrap-backend.sh local
  # Genere terraform/backends/http.tfbackend (gitignore)
  # Usage : terraform init -backend-config=../../terraform/backends/http.tfbackend
  backend "http" {}
}

# TLS Proxmox : configurer un certificat valide sur l'API Proxmox avant de deployer
# Option 1 : Let's Encrypt via le proxy Proxmox (recommande en production)
# Option 2 : CA interne — pm_tls_insecure = false (defaut securise)
# Pour CA auto-signee : ajouter pm_cafile = "/etc/ssl/certs/proxmox-ca.pem"
provider "proxmox" {
  pm_api_url  = var.proxmox_api_url
  pm_user     = var.proxmox_user
  pm_password = var.proxmox_password
}

# Apres terraform apply, configurer k3s via Ansible :
#   ansible-playbook -i inventories/proxmox/hosts.yml \
#     playbooks/00-preflight.yml playbooks/01-base-setup.yml \
#     playbooks/02-k3s-cluster.yml playbooks/03-cloud-node-config.yml
resource "proxmox_vm_qemu" "k3s_server" {
  count       = 1
  name        = "${var.cluster_name}-server-${count.index}"
  target_node = var.proxmox_node
  clone       = var.vm_template
  full_clone  = true
  cores       = 4
  memory      = 8192

  disk {
    size    = "50G"
    type    = "scsi"
    storage = var.storage_pool
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}

resource "proxmox_vm_qemu" "k3s_agent_data" {
  count       = var.data_node_count
  name        = "${var.cluster_name}-data-${count.index}"
  target_node = var.proxmox_node
  clone       = var.vm_template
  full_clone  = true
  cores       = 8
  memory      = 32768

  disk {
    size    = "500G"
    type    = "scsi"
    storage = var.storage_pool
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
