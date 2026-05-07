terraform {
  required_version = ">= 1.7, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # ── Remote state — partial backend configuration ──────────────────────────
  # Activer avec : bash scripts/bootstrap-backend.sh aws
  # Le fichier terraform/backends/s3.tfbackend est généré par le script.
  # Passé via : terraform init -backend-config=../../terraform/backends/s3.tfbackend
  #
  # Bloc vide = Terraform accepte -backend-config dynamique sans modifier ce fichier.
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name            = "${var.cluster_name}-vpc"
  cidr            = "10.10.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name              = var.cluster_name
  cluster_version           = "1.30"
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # FIX H5 : Restreindre l'accès public à des CIDRs légitimes uniquement.
  # Option recommandée en production : désactiver l'accès public et utiliser
  # un bastion ou un VPN pour accéder à l'API server.
  # Option intermédiaire : restreindre aux IPs des opérateurs et des CI runners.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.allowed_public_cidrs
  # Pour désactiver complètement l'accès public :
  # cluster_endpoint_public_access  = false
  # cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    general = {
      min_size       = 1
      max_size       = 6
      desired_size   = var.general_node_count
      instance_types = [var.general_instance_type]
      disk_size      = 100
      labels         = { role = "general" }
    }

    data = {
      min_size       = 3
      max_size       = 12
      desired_size   = var.data_node_count
      instance_types = [var.data_instance_type]
      disk_size      = 500
      labels         = { role = "hadoop-data" }

      taints = [
        {
          key    = "dedicated"
          value  = "hadoop-data"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}
