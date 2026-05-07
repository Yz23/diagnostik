terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # ── Remote state — partial backend configuration ──────────────────────────
  # Activer avec : bash scripts/bootstrap-backend.sh azure
  # Le fichier terraform/backends/azurerm.tfbackend est généré par le script.
  # Passé via : terraform init -backend-config=../../terraform/backends/azurerm.tfbackend
  #
  # Bloc vide = Terraform accepte -backend-config dynamique sans modifier ce fichier.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
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
    name            = "general"
    node_count      = var.general_node_count
    vm_size         = var.general_vm_size
    os_disk_size_gb = 100
    type            = "VirtualMachineScaleSets"
    # FIX: enable_auto_scaling deprecated since azurerm ~> 3.90, use auto_scaling_enabled
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 6
    node_labels          = { role = "general" }
  }

  identity {
    type = "SystemAssigned"
  }

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
  # FIX: enable_auto_scaling → auto_scaling_enabled
  auto_scaling_enabled = true
  min_count            = 3
  max_count            = 12
  node_labels          = { role = "hadoop-data" }
  node_taints          = ["dedicated=hadoop-data:NoSchedule"]
}
