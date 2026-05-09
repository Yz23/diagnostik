# DIAGNOSTIK — Ansible Playbooks

Automates node configuration and platform deployment.

## Playbook overview

| Playbook | Target | Description |
|---|---|---|
| `00-preflight.yml` | all | Checks OS, RAM, disk, SSH — no changes made |
| `01-base-setup.yml` | all | sysctl, ulimits, kernel modules, containerd |
| `02-k3s-cluster.yml` | Proxmox/local | Installs k3s server + agents + labels/taints |
| `03-cloud-node-config.yml` | GCP/AWS/Azure | sysctl + ulimits on managed nodes |
| `04-deploy-platform.yml` | localhost | `kustomize build` + `kubectl apply` |

## Full workflow — Proxmox/local

```bash
cd ansible/

# 1. Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# 2. Edit inventory
nano inventories/proxmox/hosts.yml  # fill in IPs

# 3. Pre-flight checks (no changes made)
ansible-playbook -i inventories/proxmox/ playbooks/00-preflight.yml

# 4. Configure base system
ansible-playbook -i inventories/proxmox/ playbooks/01-base-setup.yml

# 5. Install k3s cluster
ansible-playbook -i inventories/proxmox/ playbooks/02-k3s-cluster.yml

# 6. Deploy the platform
export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'
bash ../scripts/create-secrets.sh
ansible-playbook -i inventories/proxmox/ playbooks/04-deploy-platform.yml
```

## Full workflow — Cloud (GCP/AWS/Azure)

```bash
# Nodes already provisioned by Terraform

cd ansible/
ansible-galaxy collection install -r requirements.yml

# Cloud nodes are already configured by the provider
# Only run config + deploy:
ansible-playbook -i inventories/gcp/ playbooks/03-cloud-node-config.yml
ansible-playbook -i inventories/gcp/ playbooks/04-deploy-platform.yml
```

## Inventories

| Directory | Provider | Notes |
|---|---|---|
| `inventories/proxmox/` | k3s / Proxmox | Static inventory — fill IPs manually |
| `inventories/gcp/` | GKE | Dynamic via `google.cloud.gcp_compute` |
| `inventories/aws/` | EKS | Dynamic via `amazon.aws.aws_ec2` |
| `inventories/azure/` | AKS | Dynamic via `azure.azcollection.azure_rm` |

## Roles

| Role | Description |
|---|---|
| `common` | sysctl tuning, ulimits, swap disabled, kernel modules |
| `containerd` | Container runtime install (SystemdCgroup) |
| `k3s-server` | k3s control-plane install + kubeconfig fetch |
| `k3s-agent` | Data node join to k3s cluster |
| `k8s-node-config` | Node labels, taints, local-path, ingress-nginx |
