<div align="center">

<br/>

# 🔍 infrastructure-resiliente

### Production-grade Data Platform on Kubernetes

<br/>

[![CI](https://github.com/Yz23/infrastructure-resiliente/actions/workflows/ci.yml/badge.svg)](https://github.com/Yz23/infrastructure-resiliente/actions/workflows/ci.yml)
&nbsp;
![OpenSearch](https://img.shields.io/badge/OpenSearch-2.17.0-005EB8?logo=opensearch&logoColor=white)
&nbsp;
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-326CE5?logo=kubernetes&logoColor=white)
&nbsp;
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.6-F5A623?logo=apache&logoColor=white)
&nbsp;
![Terraform](https://img.shields.io/badge/Terraform-1.7-7B42BC?logo=terraform&logoColor=white)
&nbsp;
![License](https://img.shields.io/badge/license-Apache%202.0-22C55E?logo=apache)

<br/>

**Multi-cloud · Multi-provider · No X-Pack license required**

[Getting Started](#-getting-started) · [Architecture](#-architecture) · [Documentation](#-documentation) · [CI/CD](#-cicd) · [Security](#-security)

<br/>

</div>

---

## ✨ What is this?

A complete, production-ready data platform deployable on any Kubernetes cluster — GCP, AWS, Azure, or a local Proxmox homelab — **with a single command**.

| Component | Role | Replaces |
|---|---|---|
| **OpenSearch** | Distributed search & analytics engine | Elasticsearch + X-Pack *(paid)* |
| **OpenSearch Dashboards** | Visualization UI · port `5601` | Kibana + X-Pack *(paid)* |
| **Logstash** | Data ingestion pipeline | — *(kept, same config)* |
| **HDFS HA** | Distributed block storage across nodes | — |
| **YARN HA** | Cluster resource & job scheduling | — |

> **Why OpenSearch over Elasticsearch?**
> OpenSearch is a fork of Elasticsearch 7.10 (Apache 2.0). Security features — auth, TLS, RBAC, multi-tenancy, alerting — are **built-in and completely free**. No X-Pack subscription needed.

---

## 🏗 Architecture

```
                    ┌─────────────────────────────────────────────────┐
  Internet          │              namespace: data-platform            │
     │              │                                                  │
     ▼              │  ┌──────────────────── Search ────────────────┐  │
  Ingress (nginx)   │  │  opensearch-master       ×3  [StatefulSet] │  │
     │              │  │  opensearch-data         ×3  [StatefulSet] │  │
     ▼              │  │  opensearch-coordinator  ×2  [Deployment]  │  │
  Dashboards :5601  │  │  opensearch-dashboards   ×2  [Deployment]  │  │
                    │  └────────────────────────────────────────────┘  │
  App logs          │                                                  │
  Filebeat ──────►  │  ┌──────────────────── Ingest ────────────────┐  │
  Logstash          │  │  logstash  ×2  [Deployment]                │  │
  :5000 :5044 :8080 │  └────────────────────────────────────────────┘  │
                    │                                                  │
                    │  ┌─────────────────── HDFS HA ────────────────┐  │
                    │  │  zookeeper      ×3  [StatefulSet]          │  │
                    │  │  journalnode    ×3  [StatefulSet]          │  │
                    │  │  namenode       ×2  [StatefulSet] HA       │  │
                    │  │  datanode       ×3  [StatefulSet] 100Gi    │  │
                    │  └────────────────────────────────────────────┘  │
                    │                                                  │
                    │  ┌─────────────────── YARN HA ────────────────┐  │
                    │  │  resourcemanager  ×2  [StatefulSet] HA     │  │
                    │  │  nodemanager          [DaemonSet]          │  │
                    │  │  historyserver    ×1  [Deployment]         │  │
                    │  └────────────────────────────────────────────┘  │
                    └─────────────────────────────────────────────────┘
```

**HDFS boot sequence** — enforced automatically by `initContainers`:

```
ZooKeeper ×3  ──►  JournalNodes ×3  ──►  NameNode nn0  (format + zkfc)
                                     └►  NameNode nn1  (bootstrapStandby)
                                              │
                                              ▼
                                         DataNodes ×3
```

---

## ☁️ Multi-provider support

The `k8s/base/` layer is **100% provider-agnostic** — Kustomize overlays only patch the `StorageClass` name. Nothing else changes.

| Provider | Engine | Terraform module | Kustomize overlay | StorageClass |
|:---:|:---:|---|---|:---:|
| **GCP** | GKE | `modules/gcp-gke` | `overlays/gcp` | `premium-rwo` |
| **AWS** | EKS | `modules/aws-eks` | `overlays/aws` | `gp3` |
| **Azure** | AKS | `modules/azure-aks` | `overlays/azure` | `managed-premium` |
| **Local / Proxmox** | k3s | `modules/local-k3s` | `overlays/local` | `local-path` |

---

## 📁 Repository structure

```
.
├── 📂 k8s/
│   ├── base/                              ← provider-agnostic manifests
│   │   ├── namespace/
│   │   ├── opensearch/                    ← master · data · coordinator · PDB
│   │   ├── opensearch-dashboards/
│   │   ├── logstash/
│   │   ├── hdfs/                          ← ZooKeeper · JournalNode · NameNode · DataNode
│   │   ├── yarn/                          ← ResourceManager · NodeManager · HistoryServer
│   │   └── ingress/
│   └── overlays/
│       ├── gcp/patches/
│       ├── aws/patches/
│       ├── azure/patches/
│       └── local/patches/                 ← StorageClass + reduced resource limits
│
├── 📂 terraform/
│   ├── modules/
│   │   ├── gcp-gke/                       ← VPC + GKE cluster + node pools
│   │   ├── aws-eks/                       ← VPC + EKS cluster + managed node groups
│   │   ├── azure-aks/                     ← Resource group + AKS cluster
│   │   └── local-k3s/                     ← Proxmox VMs + k3s install via SSH
│   └── environments/
│       ├── example-gcp.tfvars
│       ├── example-aws.tfvars
│       ├── example-azure.tfvars
│       └── example-local.tfvars
│
├── 📂 docs/
│   └── guide-debutant.docx                ← Beginner guide (FR): K8s · OpenSearch · Hadoop · Terraform
│
├── 📂 scripts/
│   ├── create-secrets.sh                  ← Inject credentials as k8s Secrets
│   └── deploy.sh [gcp|aws|azure|local]    ← Ordered full-stack deploy
│
├── .github/workflows/ci.yml               ← 5-job CI pipeline
├── .env.example                           ← All environment variables documented
└── .gitignore
```

---

## 🚀 Getting started

### Prerequisites

- `kubectl` ≥ 1.28 — [install](https://kubernetes.io/docs/tasks/tools/)
- `terraform` ≥ 1.7 — [install](https://developer.hashicorp.com/terraform/install)
- `kustomize` ≥ 5.0 — [install](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- Cloud CLI (`gcloud` / `aws` / `az`) for your target provider

### Step 1 — Provision the cluster

<details>
<summary><b>☁️ GCP (GKE)</b></summary>

```bash
cd terraform/modules/gcp-gke
cp ../../environments/example-gcp.tfvars prod.tfvars
# Edit prod.tfvars: set project_id and region

export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
terraform init
terraform apply -var-file=prod.tfvars

# Configure kubectl
$(terraform output -raw kubeconfig_cmd)
```
</details>

<details>
<summary><b>☁️ AWS (EKS)</b></summary>

```bash
cd terraform/modules/aws-eks
cp ../../environments/example-aws.tfvars prod.tfvars

export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
terraform init
terraform apply -var-file=prod.tfvars

$(terraform output -raw kubeconfig_cmd)
```
</details>

<details>
<summary><b>☁️ Azure (AKS)</b></summary>

```bash
az login
cd terraform/modules/azure-aks
terraform init
terraform apply -var-file=../../environments/example-azure.tfvars

$(terraform output -raw kubeconfig_cmd)
```
</details>

<details>
<summary><b>🖥️ Local / Proxmox (k3s)</b></summary>

```bash
export PM_API_URL=https://192.168.1.100:8006/api2/json
export PM_USER=root@pam
export PM_PASS=yourpassword

cd terraform/modules/local-k3s
terraform init
terraform apply -var-file=../../environments/example-local.tfvars

$(terraform output -raw kubeconfig_cmd)

# Install local-path-provisioner for PVCs
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```
</details>

### Step 2 — Create secrets

```bash
cd <repo-root>
export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'
bash scripts/create-secrets.sh
```

### Step 3 — Deploy

```bash
# Choose: gcp | aws | azure | local
bash scripts/deploy.sh gcp
```

### Step 4 — Verify

```bash
# All pods running?
kubectl -n data-platform get pods -o wide

# OpenSearch cluster health
kubectl -n data-platform port-forward svc/opensearch 9200:9200 &
curl -u admin:YourStr0ng!Pass1 http://localhost:9200/_cluster/health?pretty

# Dashboards  →  http://localhost:5601
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601 &

# HDFS UI  →  http://localhost:9870
kubectl -n data-platform port-forward svc/hdfs-namenode 9870:9870 &

# YARN UI  →  http://localhost:8088
kubectl -n data-platform port-forward svc/yarn-resourcemanager 8088:8088 &
```

---

## ⚙️ Configuration

### Environment variables

Copy `.env.example` → `.env` for local reference. In production, **all secrets use `kubectl create secret`** — never env files.

| Variable | Default | Description |
|---|:---:|---|
| `OPENSEARCH_VERSION` | `2.17.0` | OpenSearch + Dashboards image tag |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | — | **k8s Secret only** — never in files |
| `OS_MASTER_HEAP` | `1g` | JVM heap — master nodes |
| `OS_DATA_HEAP` | `2g` | JVM heap — data nodes |
| `LS_HEAP_SIZE` | `1g` | JVM heap — Logstash |
| `PROVIDER` | `gcp` | Active overlay: `gcp` / `aws` / `azure` / `local` |

### Changing StorageClass

Edit the relevant overlay patch — this is the **only** file that differs between providers:

```yaml
# k8s/overlays/<provider>/patches/storageclass.yaml
- op: replace
  path: /spec/volumeClaimTemplates/0/spec/storageClassName
  value: premium-rwo   # ← your StorageClass name here
```

---

## 🔧 Operations

### Scale nodes

```bash
# Add OpenSearch data nodes
kubectl -n data-platform scale statefulset opensearch-data --replicas=5

# Add HDFS data nodes
kubectl -n data-platform scale statefulset hdfs-datanode --replicas=5
```

### Rolling upgrade — OpenSearch

```bash
# Always: data nodes first → masters → coordinator
kubectl -n data-platform set image statefulset/opensearch-data \
  opensearch=opensearchproject/opensearch:2.18.0
kubectl -n data-platform rollout status statefulset/opensearch-data --timeout=300s

kubectl -n data-platform set image statefulset/opensearch-master \
  opensearch=opensearchproject/opensearch:2.18.0
kubectl -n data-platform rollout status statefulset/opensearch-master --timeout=300s
```

### Quick access (no Ingress)

```bash
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601 &  # → :5601
kubectl -n data-platform port-forward svc/hdfs-namenode         9870:9870 &  # → :9870
kubectl -n data-platform port-forward svc/yarn-resourcemanager  8088:8088 &  # → :8088
```

### Cluster health checks

```bash
# OpenSearch
curl -u admin:$PASS http://localhost:9200/_cluster/health?pretty

# HDFS — active NameNode
kubectl -n data-platform exec hdfs-namenode-0 -- hdfs haadmin -getServiceState nn0

# YARN — active ResourceManager
kubectl -n data-platform exec yarn-resourcemanager-0 -- yarn rmadmin -getServiceState rm0
```

---

## 🔒 Security

| Control | Status | Notes |
|---|:---:|---|
| Passwords stored as k8s Secrets | ✅ | Never in manifests or git |
| Cloud credentials | ✅ | ADC / Workload Identity / env vars |
| OpenSearch auth + RBAC | ✅ | Built-in security plugin — no license |
| Pods run as non-root | ✅ | `runAsUser: 1000`, `fsGroup: 1000` |
| PodDisruptionBudgets | ✅ | Prevents accidental mass eviction |
| Anti-affinity rules | ✅ | Master/data pods spread across nodes |
| TLS — HTTPS end-to-end | ⬜ | Uncomment `cert-manager` annotations in `ingress.yaml` |
| Kubernetes NetworkPolicies | ⬜ | Add to restrict pod-to-pod traffic |
| Remote Terraform state | ⬜ | Uncomment `backend "gcs"` in `main.tf` |

---

## 🧪 CI/CD

Every push and pull request triggers the full pipeline:

| Job | Tool | What is checked |
|---|---|---|
| `secret-scan` | **Gitleaks** | No secrets or keys anywhere in git history |
| `kube-validate` | **kubeconform** | All manifests valid against Kubernetes 1.30 schema |
| `kustomize-build` | **kustomize** | All 4 overlays build without errors |
| `terraform-validate` | **Terraform** | `fmt` + `validate` on all 4 modules |
| `no-hardcoded-secrets` | **grep** | No `changeme` / `CHANGE_ME` in YAML files |

---

## 📚 Documentation

| Document | Description |
|---|---|
| [`docs/guide-debutant.docx`](docs/guide-debutant.docx) | 📖 Beginner guide (FR) — Kubernetes, OpenSearch, Hadoop HDFS/YARN, Terraform explained from scratch with analogies, commands and glossaries |

---

## 🤝 Contributing

1. Fork the repo and create a branch: `git checkout -b feat/my-feature`
2. Make your changes — run `terraform fmt` and `kustomize build` locally to validate
3. Push and open a Pull Request — CI will run automatically
4. All 5 CI jobs must pass before merge

---

<div align="center">

<br/>

Built with &nbsp;
[OpenSearch](https://opensearch.org) &nbsp;·&nbsp;
[Apache Hadoop](https://hadoop.apache.org) &nbsp;·&nbsp;
[Kubernetes](https://kubernetes.io) &nbsp;·&nbsp;
[Terraform](https://terraform.io)

<br/>

![Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-22C55E)

<br/>

</div>
