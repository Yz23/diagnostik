# DIAGNOSTIK — Ansible Playbooks

Automatise la configuration des nœuds et le déploiement de la plateforme.

## Rôle de chaque playbook

| Playbook | Cible | Description |
|---|---|---|
| `00-preflight.yml` | tous | Vérifie OS, RAM, disk, SSH — sans rien modifier |
| `01-base-setup.yml` | tous | sysctl, ulimits, kernel modules, containerd |
| `02-k3s-cluster.yml` | Proxmox/local | Installe k3s server + agents + labels/taints |
| `03-cloud-node-config.yml` | GCP/AWS/Azure | sysctl + ulimits sur nœuds managés |
| `04-deploy-platform.yml` | localhost | `kustomize build` + `kubectl apply` |

## Workflow complet — Proxmox/local

```bash
cd ansible/

# 1. Installer les collections Ansible
ansible-galaxy collection install -r requirements.yml

# 2. Éditer l'inventaire
nano inventories/proxmox/hosts.yml  # remplir les IPs

# 3. Vérifications préalables (rien n'est modifié)
ansible-playbook -i inventories/proxmox/ playbooks/00-preflight.yml

# 4. Configurer le système de base
ansible-playbook -i inventories/proxmox/ playbooks/01-base-setup.yml

# 5. Installer k3s
ansible-playbook -i inventories/proxmox/ playbooks/02-k3s-cluster.yml
# → génère kubeconfig-server-0.yaml à la racine du repo

# 6. Configurer kubectl
export KUBECONFIG=$(pwd)/../kubeconfig-server-0.yaml

# 7. Créer les secrets
export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'
bash ../scripts/create-secrets.sh

# 8. Déployer la plateforme
PROVIDER=local ansible-playbook playbooks/04-deploy-platform.yml
```

## Workflow — GCP/AWS/Azure (nœuds managés)

```bash
# Sur GKE/EKS/AKS, k3s n'est pas nécessaire.
# On configure uniquement le système et on déploie.

# Configurer kubectl (après terraform apply)
$(terraform -chdir=terraform/modules/gcp-gke output -raw kubeconfig_cmd)

# Optionnel : configurer sysctl/ulimits si accès SSH aux nœuds
ansible-playbook -i inventories/gcp/ playbooks/03-cloud-node-config.yml

# Déployer
export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'
bash scripts/create-secrets.sh
PROVIDER=gcp ansible-playbook ansible/playbooks/04-deploy-platform.yml
```
