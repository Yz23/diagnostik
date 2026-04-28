variable "project_id"           { type = string }
variable "region"               { type = string; default = "europe-west1" }
variable "cluster_name"         { type = string; default = "data-platform" }
variable "general_node_count"   { type = number; default = 2 }
variable "data_node_count"      { type = number; default = 3 }
variable "general_machine_type" { type = string; default = "e2-standard-4" }
variable "data_machine_type"    { type = string; default = "n2-highmem-8" }
