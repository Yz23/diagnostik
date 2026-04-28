# infrastructure-resiliente

Production-grade data platform on Kubernetes — **multi-cloud / multi-provider**, **OpenSearch**, **HDFS HA**, **YARN**.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes cluster                         │
│                  namespace: data-platform                     │
│                                                               │
│  ┌──────────── Search ─────────────┐                         │
│  │  opensearch-master  x3 (StatefulSet, quorum)              │
│  │  opensearch-data    x3 (StatefulSet, PVC)                 │
│  │  opensearch-coord   x2 (Deployment, stateless)            │
│  │  opensearch-dashboards x2                                  │
│  └─────────────────────────────────┘                         │
│                                                               │
│  ┌──────────── Ingestion ──────────┐                         │
│  │  logstash x2                    │                         │
│  └─────────────────────────────────┘                         │
│                                                               │
│  ┌──────────── Distributed Storage (HDFS HA) ─────────────┐  │
│  │  zookeeper       x3  ← quorum for NameNode + RM HA     │  │
│  │  hdfs-journalnode x3 ← shared edit log (quorum write)  │  │
│  │  hdfs-namenode   x2  ← active/standby + ZKFC           │  │
│  │  hdfs-datanode   x3  ← block storage, PVC 100Gi each   │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────── Resource Management (YARN HA) ─────────────┐  │
│  │  yarn-resourcemanager x2  ← active/standby via ZK      │  │
│  │  yarn-nodemanager         ← DaemonSet on hadoop-data    │  │
│  │  yarn-historyserver  x1                                 │  │
│  └─────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Multi-provider approach

| Provider | K8s engine | Terraform module       | Kustomize overlay | StorageClass  |
|----------|------------|------------------------|-------------------|---------------|
| GCP      | GKE        | `modules/gcp-gke`      | `overlays/gcp`    | `premium-rwo` |
| AWS      | EKS        | `modules/aws-eks`      | `overlays/aws`    | `gp3`         |
| Azure    | AKS        | `modules/azure-aks`    | `overlays/azure`  | `managed-premium` |
| Local    | k3s/Proxmox| `modules/local-k3s`    | `overlays/local`  | `local-path`  |

The **base** layer (`k8s/base/`) is identical for all providers.  
Only StorageClass names and resource sizes differ per overlay — nothing else.

---

## Repository structure

```
.
├── k8s/
│   ├── base/                         ← provider-agnostic manifests
│   │   ├── namespace/
│   │   ├── opensearch/               ← master, data, coordinator, services, PDB
│   │   ├── opensearch-dashboards/
│   │   ├── logstash/
│   │   ├── hdfs/                     ← ZooKeeper, JournalNode, NameNode, DataNode
│   │   ├── yarn/                     ← ResourceManager, NodeManager, HistoryServer
│   │   └── ingress/
│   └── overlays/
│       ├── gcp/patches/              ← StorageClass: premium-rwo
│       ├── aws/patches/              ← StorageClass: gp3
│       ├── azure/patches/            ← StorageClass: managed-premium
│       └── local/patches/            ← StorageClass: local-path + smaller resources
│
├── terraform/
│   ├── modules/
│   │   ├── gcp-gke/                  ← VPC + GKE cluster + node pools
│   │   ├── aws-eks/                  ← VPC + EKS cluster + managed node groups
│   │   ├── azure-aks/               ← Resource group + AKS + node pools
│   │   └── local-k3s/               ← Proxmox VMs + k3s install via SSH
│   └── environments/
│       ├── example-gcp.tfvars
│       ├── example-aws.tfvars
│       ├── example-azure.tfvars
│       └── example-local.tfvars
│
├── scripts/
│   ├── create-secrets.sh
│   └── deploy.sh [gcp|aws|azure|local]
│
├── .github/workflows/ci.yml
├── .env.example
└── .gitignore
```

---

## Quick start

### 1 — Provision the cluster

**GCP:**
```bash
cd terraform/modules/gcp-gke
cp ../../environments/example-gcp.tfvars prod.tfvars
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
terraform init && terraform apply -var-file=prod.tfvars
$(terraform output -raw kubeconfig_cmd)
```

**AWS:**
```bash
cd terraform/modules/aws-eks
cp ../../environments/example-aws.tfvars prod.tfvars
export AWS_ACCESS_KEY_ID=... && export AWS_SECRET_ACCESS_KEY=...
terraform init && terraform apply -var-file=prod.tfvars
$(terraform output -raw kubeconfig_cmd)
```

**Azure:**
```bash
az login
cd terraform/modules/azure-aks
terraform init && terraform apply -var-file=../../environments/example-azure.tfvars
$(terraform output -raw kubeconfig_cmd)
```

**Local / Proxmox:**
```bash
export PM_API_URL=https://192.168.1.100:8006/api2/json
export PM_USER=root@pam && export PM_PASS=yourpassword
cd terraform/modules/local-k3s
terraform init && terraform apply -var-file=../../environments/example-local.tfvars
$(terraform output -raw kubeconfig_cmd)
# Install local-path-provisioner for PVCs:
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### 2 — Create secrets
```bash
cd <repo-root>
export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'
bash scripts/create-secrets.sh
```

### 3 — Deploy
```bash
# Replace 'gcp' with: aws | azure | local
bash scripts/deploy.sh gcp
```

### 4 — Verify
```bash
kubectl -n data-platform get pods -o wide

# HDFS health
kubectl -n data-platform port-forward svc/hdfs-namenode 9870:9870 &
# → http://localhost:9870  (NameNode UI)

# YARN
kubectl -n data-platform port-forward svc/yarn-resourcemanager 8088:8088 &
# → http://localhost:8088  (ResourceManager UI)

# OpenSearch
kubectl -n data-platform port-forward svc/opensearch 9200:9200 &
curl -u admin:YourStr0ng!Pass1 http://localhost:9200/_cluster/health?pretty

# Dashboards
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601 &
# → http://localhost:5601
```

---

## HDFS startup order

The init containers enforce the correct boot sequence automatically:

```
ZooKeeper (x3) → JournalNodes (x3) → NameNode nn0 (format + zkfc)
                                    → NameNode nn1 (bootstrapStandby)
                                    → DataNodes (x3)
```

YARN waits for ZooKeeper; NodeManagers wait for a ResourceManager to be ready.

---

## StorageClass reference

| Provider | General SC     | Data node SC   | Notes                          |
|----------|---------------|----------------|--------------------------------|
| GCP      | `standard-rwo` | `premium-rwo` | pd-balanced / pd-ssd           |
| AWS      | `gp2`          | `gp3`         | EBS general / provisioned IOPS |
| Azure    | `default`      | `managed-premium` | Standard HDD / Premium SSD |
| Local    | `local-path`   | `local-path`  | Rancher local-path-provisioner |

---

## CI/CD

| Job                    | Tool          | Coverage                              |
|------------------------|---------------|---------------------------------------|
| `secret-scan`          | Gitleaks      | Full git history                      |
| `kube-validate`        | kubeconform   | All base manifests vs k8s 1.30 schema |
| `kustomize-build`      | kustomize     | All 4 overlays build without errors   |
| `terraform-validate`   | Terraform     | All 4 modules — fmt + validate        |
| `no-hardcoded-secrets` | grep          | No `changeme`/`CHANGE_ME` in YAML     |
