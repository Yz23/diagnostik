# ── Local / Proxmox k3s Module ─────────────────────────────────
# Provisions VMs on Proxmox via the Telmate provider,
# then installs k3s on them using a remote-exec provisioner.
#
# Requirements:
#   terraform init
#   export PM_API_URL=https://proxmox-host:8006/api2/json
#   export PM_USER=root@pam
#   export PM_PASS=yourpassword
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

# Control-plane VM
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
  network { model = "virtio"; bridge = "vmbr0" }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --disable traefik' sh -",
      "sudo cat /etc/rancher/k3s/k3s.yaml"
    ]
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
    }
  }
}

# Data node VMs
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
  network { model = "virtio"; bridge = "vmbr0" }

  provisioner "remote-exec" {
    inline = [
      # Join the k3s cluster as agent
      "curl -sfL https://get.k3s.io | K3S_URL=https://${proxmox_vm_qemu.k3s_server[0].default_ipv4_address}:6443 K3S_TOKEN=$(ssh ${var.vm_user}@${proxmox_vm_qemu.k3s_server[0].default_ipv4_address} 'sudo cat /var/lib/rancher/k3s/server/node-token') sh -",
      # Label node for Hadoop data scheduling
      "kubectl label node $(hostname) role=hadoop-data",
      "kubectl taint node $(hostname) dedicated=hadoop-data:NoSchedule"
    ]
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
    }
  }
}
