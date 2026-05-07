terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
  # ── Remote state — partial backend configuration ──────────────────────────
  # Activer avec : bash scripts/bootstrap-backend.sh local
  # Le fichier terraform/backends/http.tfbackend est généré par le script.
  # Passé via : terraform init -backend-config=../../terraform/backends/http.tfbackend
  #
  # Bloc vide = Terraform accepte -backend-config dynamique sans modifier ce fichier.
  backend "http" {}
}

provider "proxmox" {
  pm_api_url  = var.proxmox_api_url
  pm_user     = var.proxmox_user
  pm_password = var.proxmox_password
  # FIX C3 : SUPPRIMER pm_tls_insecure = true
  # Prérequis : configurer un certificat TLS valide sur l'API Proxmox.
  # Option 1 : Let's Encrypt via le proxy Proxmox (recommandé en production)
  # Option 2 : CA interne → pm_tls_insecure = false + PM_TLS_INSECURE non défini
  # Si un certificat auto-signé est utilisé, spécifier la CA :
  # pm_cafile = "/etc/ssl/certs/proxmox-ca.pem"
}

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

  # FIX H3 : remote-exec supprimé.
  # L'installation de k3s et la configuration des nœuds sont entièrement
  # déléguées aux rôles Ansible (k3s-server, k3s-agent, k8s-node-config).
  # Cela évite :
  #   - l'exposition du node-token dans les logs Terraform et le process list
  #   - le curl|sh sans vérification de signature
  #   - les commandes SSH imbriquées fragiles
  #
  # Usage après `terraform apply` :
  #   ansible-playbook -i inventories/proxmox/hosts.yml \
  #     playbooks/00-preflight.yml \
  #     playbooks/01-base-setup.yml \
  #     playbooks/02-k3s-cluster.yml \
  #     playbooks/03-cloud-node-config.yml
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

  # FIX H3 : remote-exec supprimé — voir commentaire ci-dessus.
}
