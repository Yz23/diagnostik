<div align="center">

# infrastructure-resiliente

**Production-grade data platform · Kubernetes · OpenSearch · HDFS HA · YARN**

[![CI](https://github.com/Yz23/infrastructure-resiliente/actions/workflows/ci.yml/badge.svg)](https://github.com/Yz23/infrastructure-resiliente/actions/workflows/ci.yml)
![OpenSearch](https://img.shields.io/badge/OpenSearch-2.17-blue?logo=opensearch)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-326CE5?logo=kubernetes&logoColor=white)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.6-yellow?logo=apache)
![Terraform](https://img.shields.io/badge/Terraform-1.7-7B42BC?logo=terraform)
![License](https://img.shields.io/badge/license-Apache%202.0-green)

*Multi-cloud · Multi-provider · No X-Pack license required*

</div>

---

## Overview

This repo provisions a complete data platform — search, ingestion, distributed storage, and resource management — on any Kubernetes cluster, with a single command per environment.

| Component | Role | Replaces |
|---|---|---|
| **OpenSearch** | Distributed search & analytics | Elasticsearch + X-Pack |
| **OpenSearch Dashboards** | Visualization UI (port 5601) | Kibana + X-Pack |
| **Logstash** | Data ingestion pipeline | — (kept as-is) |
| **HDFS HA** | Distributed block storage | — |
| **YARN HA** | Cluster resource management | — |

> **Why OpenSearch?** It is a fork of Elasticsearch 7.10 (Apache 2.0 license). Security — authentication, TLS, RBAC, multi-tenancy, alerting — is built-in and free. No X-Pack license needed.

---

## Architecture

```
                         ┌──────────────────────────────────────────┐
  Internet               │         namespace: data-platform          │
     │                   │                                           │
     ▼                   │  ┌─────────────── Search ──────────────┐  │
  Ingress                │  │  opensearch-master      ×3  [STS]   │  │
  (nginx)                │  │  opensearch-data        ×3  [STS]   │  │
     │                   │  │  opensearch-coordinator ×2  [Deploy]│  │
     ▼                   │  │  opensearch-dashboards  ×2  [Deploy]│  │
  Dashboards :5601       │  └─────────────────────────────────────┘  │
                         │                                           │
  App logs               │  ┌──────────────── Ingest ─────────────┐  │
  Filebeat ──► Logstash  │  │  logstash ×2  [Deploy]              │  │
               :5000     │  └─────────────────────────────────────┘  │
               :5044     │                                           │
               :8080     │  ┌──────────── HDFS HA ────────────────┐  │
                         │  │  zookeeper      ×3  [STS]           │  │
                         │  │  journalnode    ×3  [STS]           │  │
                         │  │  namenode       ×2  [STS] active/sb │  │
                         │  │  datanode       ×3  [STS] 100Gi/pod │  │
                         │  └─────────────────────────────────────┘  │
                         │                                           │
                         │  ┌──────────── YARN HA ────────────────┐  │
                         │  │  resourcemanager ×2  [STS]          │  │
                         │  │  nodemanager        [DaemonSet]     │  │
                         │  │  historyserver   ×1  [Deploy]       │  │
                         │  └─────────────────────────────────────┘  │
                         └───────────────────────────────────────────┘
```

**HDFS startup order** (enforced by `initContainers`):

```
ZooKeeper ×3  ──►  JournalNodes ×3  ──►  NameNode nn0 (format + zkfc)
                                     ──►  NameNode nn1 (bootstrapStandby)
                                     ──►  DataNodes ×3
```

---

## Multi-provider support

The `k8s/base/` layer is **100% provider-agnostic**. Overlays only patch the `StorageClass` name.

| Provider | Kubernetes | Terraform module | Overlay | StorageClass |
|---|---|---|---|---|
| GCP | GKE | `modules/gcp-gke` | `overlays/gcp` | `premium-rwo` |
| AWS | EKS | `modules/aws-eks` | `overlays/aws` | `gp3` |
| Azure | AKS | `modules/azure-aks` | `overlays/azure` | `managed-premium` |
| Local / Proxmox | k3s | `modules/local-k3s` | `overlays/local` | `local-path` |

---

## Repository structure

```
.
├── k8s/
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
│       └── local/patches/                 ← also reduces resource limits
│
├── terraform/
│   ├── modules/
│   │   ├── gcp-gke/                       ← VPC + GKE + node pools
│   │   ├── aws-eks/                       ← VPC + EKS + managed node groups
│   │   ├── azure-aks/                     ← Resource group + AKS
│   │   └── local-k3s/                     ← Proxmox VMs + k3s via SSH
│   └── environments/
│       ├── example-gcp.tfvars
│       ├── example-aws.tfvars
│       ├── example-azure.tfvars
│       └── example-local.tfvars
│
├── scripts/
│   ├── create-secrets.sh                  ← inject passwords as k8s Secrets
│   └── deploy.sh [gcp|aws|azure|local]    ← ordered full-stack deploy
│
├── .github/workflows/ci.yml               ← 5-job CI pipeline
├── .env.example
└── .gitignore
```

---

## Getting started

### Step 1 — Provision the cluster

<details>
<summary><b>GCP (GKE)</b></summary>

```bash
cd terraform/modules/gcp-gke
cp ../../environments/example-gcp.tfvars prod.tfvars
# Edit prod.tfvars with your project_id and region

export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
terraform init
terraform apply -var-file=prod.tfvars

# Configure kubectl
$(terraform output -raw kubeconfig_cmd)
```
</details>

<details>
<summary><b>AWS (EKS)</b></summary>

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
<summary><b>Azure (AKS)</b></summary>

```bash
az login
cd terraform/modules/azure-aks
terraform init
terraform apply -var-file=../../environments/example-azure.tfvars

$(terraform output -raw kubeconfig_cmd)
```
</details>

<details>
<summary><b>Local / Proxmox (k3s)</b></summary>

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
# gcp | aws | azure | local
bash scripts/deploy.sh gcp
```

### Step 4 — Verify

```bash
kubectl -n data-platform get pods -o wide

# OpenSearch cluster health
kubectl -n data-platform port-forward svc/opensearch 9200:9200 &
curl -u admin:YourStr0ng!Pass1 http://localhost:9200/_cluster/health?pretty

# Dashboards (replaces Kibana)
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601 &
open http://localhost:5601

# HDFS NameNode UI
kubectl -n data-platform port-forward svc/hdfs-namenode 9870:9870 &
open http://localhost:9870

# YARN ResourceManager UI
kubectl -n data-platform port-forward svc/yarn-resourcemanager 8088:8088 &
open http://localhost:8088
```

---

## Configuration

### Environment variables

Copy `.env.example` to `.env` for local reference. In production, all secrets go through `kubectl create secret`.

| Variable | Default | Description |
|---|---|---|
| `OPENSEARCH_VERSION` | `2.17.0` | OpenSearch + Dashboards image tag |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | — | **Set via k8s Secret only** |
| `OS_MASTER_HEAP` | `1g` | JVM heap for master nodes |
| `OS_DATA_HEAP` | `2g` | JVM heap for data nodes |
| `LS_HEAP_SIZE` | `1g` | JVM heap for Logstash |
| `PROVIDER` | `gcp` | Target overlay (`gcp`/`aws`/`azure`/`local`) |

### StorageClass

Override the default `standard` class by editing the relevant overlay patch:

```yaml
# k8s/overlays/gcp/patches/storageclass.yaml
- op: replace
  path: /spec/volumeClaimTemplates/0/spec/storageClassName
  value: premium-rwo   # ← change this
```

---

## Operations

### Scale data nodes

```bash
kubectl -n data-platform scale statefulset opensearch-data --replicas=5
kubectl -n data-platform scale statefulset hdfs-datanode --replicas=5
```

### Rolling upgrade (OpenSearch)

```bash
# Data nodes first, then masters, then coordinator
kubectl -n data-platform set image statefulset/opensearch-data \
  opensearch=opensearchproject/opensearch:2.18.0
kubectl -n data-platform rollout status statefulset/opensearch-data
```

### Access UIs without Ingress

```bash
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601  # Dashboards
kubectl -n data-platform port-forward svc/hdfs-namenode 9870:9870           # HDFS
kubectl -n data-platform port-forward svc/yarn-resourcemanager 8088:8088    # YARN
```

---

## Security

| Control | Status | Notes |
|---|---|---|
| Passwords in k8s Secrets | ✅ | Never in manifests or git |
| GCP credentials | ✅ | ADC / Workload Identity |
| OpenSearch auth + RBAC | ✅ | Built-in, no license |
| Pods run as non-root | ✅ | `runAsUser: 1000` |
| PodDisruptionBudgets | ✅ | Prevents accidental wipe |
| TLS (HTTPS) | ⬜ | Uncomment cert-manager in `ingress.yaml` |
| NetworkPolicies | ⬜ | Add to restrict pod-to-pod traffic |

---

## CI/CD

Every push and PR triggers:

| Job | Tool | Checks |
|---|---|---|
| `secret-scan` | Gitleaks | No secrets in git history |
| `kube-validate` | kubeconform | All manifests valid against k8s 1.30 |
| `kustomize-build` | kustomize | All 4 overlays build cleanly |
| `terraform-validate` | Terraform | fmt + validate on all 4 modules |
| `no-hardcoded-secrets` | grep | No `changeme` / `CHANGE_ME` in YAML |

---

<div align="center">
<sub>Built with OpenSearch · Apache Hadoop · Kubernetes · Terraform · Apache 2.0</sub>
</div>
