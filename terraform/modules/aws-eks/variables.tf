variable "cluster_name" {
  type    = string
  default = "data-platform"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "general_node_count" {
  type    = number
  default = 2
}

variable "data_node_count" {
  type    = number
  default = 3
}

variable "general_instance_type" {
  type    = string
  default = "m6i.xlarge"
}

variable "data_instance_type" {
  type    = string
  default = "r6i.2xlarge"
}

variable "allowed_public_cidrs" {
  description = "CIDRs autorisés à accéder à l'API server EKS depuis Internet. Restreindre aux IPs des opérateurs et CI runners. Utiliser [] pour désactiver l'accès public."
  type        = list(string)
  default     = ["0.0.0.0/0"]
  # En production, remplacer par les CIDRs réels, par ex :
  # default = ["203.0.113.0/24", "198.51.100.0/24"]
}
