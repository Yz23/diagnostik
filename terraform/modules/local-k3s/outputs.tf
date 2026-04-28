output "kubeconfig_cmd" {
  value = "ssh ${var.vm_user}@${proxmox_vm_qemu.k3s_server[0].default_ipv4_address} 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config"
}
output "server_ip" {
  value = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
}
