terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.cluster_name}-rg"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.30"

  default_node_pool {
    name                = "general"
    node_count          = var.general_node_count
    vm_size             = var.general_vm_size
    os_disk_size_gb     = 100
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 6
    node_labels         = { role = "general" }
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "data" {
  name                  = "data"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.data_vm_size
  node_count            = var.data_node_count
  os_disk_size_gb       = 500
  enable_auto_scaling   = true
  min_count             = 3
  max_count             = 12
  node_labels           = { role = "hadoop-data" }
  node_taints           = ["dedicated=hadoop-data:NoSchedule"]
}
