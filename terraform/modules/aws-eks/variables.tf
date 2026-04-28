variable "cluster_name"          { type = string; default = "data-platform" }
variable "region"                { type = string; default = "eu-west-1" }
variable "general_node_count"    { type = number; default = 2 }
variable "data_node_count"       { type = number; default = 3 }
variable "general_instance_type" { type = string; default = "m6i.xlarge" }
variable "data_instance_type"    { type = string; default = "r6i.2xlarge" }
