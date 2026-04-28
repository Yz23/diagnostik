variable "cluster_name"        { type = string; default = "data-platform" }
variable "location"            { type = string; default = "westeurope" }
variable "general_node_count"  { type = number; default = 2 }
variable "data_node_count"     { type = number; default = 3 }
variable "general_vm_size"     { type = string; default = "Standard_D4s_v3" }
variable "data_vm_size"        { type = string; default = "Standard_E8s_v3" }
