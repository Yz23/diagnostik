<div align="center">

<br/>

# infrastructure-resiliente

### Production-grade Data Platform · Built for large-scale AI data collection & training pipelines

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
![Ansible](https://img.shields.io/badge/Ansible-2.16-EE0000?logo=ansible&logoColor=white)
&nbsp;
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
&nbsp;
![License](https://img.shields.io/badge/license-Apache%202.0-22C55E?logo=apache)

<br/>

**Multi-cloud · Multi-provider · No X-Pack license · Production-hardened**

[Purpose](#purpose) · [Architecture](#architecture) · [Getting Started](#getting-started) · [Local Dev](#local-dev-docker) · [Providers](#multi-provider-support) · [CI/CD](#cicd) · [Security](#security) · [Docs](#documentation)

<br/>

</div>

---


## Quick Start

```bash
cp .env.example .env               # définir OPENSEARCH_INITIAL_ADMIN_PASSWORD
make setup                         # restaurer +x sur les scripts (1 fois après clone)
make dev                           # démarrer la stack locale (Docker Compose)
make deploy PROVIDER=gcp           # déployer en production (Terraform + Ansible + kubectl)
make validate                      # lint manifests K8s + kustomize + terraform fmt
make help                          # toutes les commandes disponibles
```

> **Dev local (sans Kubernetes)** — `make dev` démarre la stack complète (OpenSearch, Logstash, HDFS, YARN) via Docker Compose. Les configs sont montées depuis `config/` — la même source de vérité que Kubernetes.

---

## Purpose

This repository provisions the **infrastructure layer** of a multimodal AI search engine — designed to collect, store, process and index large volumes of data at scale.

The platform is built around three core concerns:

| Concern | Answer |
|---|---|
| **Collect** at scale | Logstash ingestion pipeline · HDFS distributed storage |
| **Process** at scale | YARN resource management · Hadoop-native compute |
| **Search & index** | OpenSearch cluster · Dashboards UI |

> **Current phase — Infrastructure only.** The application layer (scrapers, ML training jobs, model serving) is not yet deployed. This repo establishes the foundation that will support it.

---

## Architecture

```
                    ┌─────────────────────────────────────────────────┐
  Internet          │              namespace: data-platform            │
     │              │                                                  │
     ▼              │  ┌──────────────────── Search ────────────────┐  │
  Ingress (nginx)   │  │  opensearch-master       x3  [StatefulSet] │  │
     │              │  │  opensearch-data         x3  [StatefulSet] │  │
     ▼              │  │  opensearch-coordinator  x2  [Deployment]  │  │
  Dashboards :5601  │  │  opensearch-dashboards   x2  [Deployment]  │  │
                    │  └────────────────────────────────────────────┘  │
  Data ingestion    │                                                  │
  Scrapers ──────►  │  ┌──────────────────── Ingest ────────────────┐  │
  Logstash          │  │  logstash  x2  [Deployment]                │  │
  :5000 :5044 :8080 │  └────────────────────────────────────────────┘  │
                    │                                                  │
                    │  ┌─────────────── Distributed Storage ────────┐  │
                    │  │  zookeeper      x3  [StatefulSet]          │  │
                    │  │  journalnode    x3  [StatefulSet]          │  │
                    │  │  namenode       x2  [StatefulSet] HA       │  │
                    │  │  datanode       x3  [StatefulSet] 100Gi    │  │
                    │  └────────────────────────────────────────────┘  │
                    │                                                  │
                    │  ┌──────────── Resource Management ────────────┐  │
                    │  │  resourcemanager  x2  [StatefulSet] HA     │  │
                    │  │  nodemanager          [DaemonSet]          │  │
                    │  │  historyserver    x1  [Deployment]         │  │
                    │  └────────────────────────────────────────────┘  │
                    └─────────────────────────────────────────────────┘
```

**HDFS boot sequence** — enforced automatically by `initContainers`:
```
ZooKeeper x3  -->  JournalNodes x3  -->  NameNode nn0  (format + zkfc)
                                    -->  NameNode nn1  (bootstrapStandby)
                                              |
                                              v
                                         DataNodes x3
```

---

## Stack decisions

| Choice | Alternative considered | Why |
|---|---|---|
| **OpenSearch** | Elasticsearch | Security (auth, RBAC, TLS) built-in — no X-Pack license |
| **HDFS HA** | MinIO / S3 | Native YARN integration for future Spark/MapReduce jobs |
| **YARN HA** | Kubernetes Jobs only | Resource isolation between ingestion and training workloads |
| **Kustomize** | Helm | No templating language — overlays are plain YAML diffs |
| **k3s (local)** | minikube / kind | Lightweight, production-like, runs on Proxmox VMs |
| **Ansible** | Terraform remote-exec | Idempotent, readable, replays without side effects |

---

## Multi-provider support

The `k8s/base/` layer is **100% provider-agnostic**. Kustomize overlays patch only the `StorageClass` name — nothing else changes between environments.

| Provider | Engine | Terraform module | Kustomize overlay | StorageClass |
|:---:|:---:|---|---|:---:|
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
│   │   ├── logstash/                      ← TCP · Beats · HTTP inputs → OpenSearch
│   │   ├── hdfs/                          ← ZooKeeper · JournalNode · NameNode · DataNode
│   │   ├── yarn/                          ← ResourceManager · NodeManager · HistoryServer
│   │   └── ingress/                       ← nginx · sticky sessions · rate limiting
│   └── overlays/
│       ├── gcp/patches/
│       ├── aws/patches/
│       ├── azure/patches/
│       └── local/patches/                 ← StorageClass + reduced resource limits
│
├── terraform/
│   ├── modules/
│   │   ├── gcp-gke/                       ← VPC + GKE regional cluster + node pools
│   │   ├── aws-eks/                       ← VPC + EKS + managed node groups
│   │   ├── azure-aks/                     ← Resource group + AKS
│   │   └── local-k3s/                     ← Proxmox VMs provisioning
│   └── environments/
│       ├── example-gcp.tfvars
│       ├── example-aws.tfvars
│       ├── example-azure.tfvars
│       └── example-local.tfvars
│
├── ansible/
│   ├── roles/
│   │   ├── common/                        ← sysctl · ulimits · kernel modules · swap
│   │   ├── containerd/                    ← container runtime (SystemdCgroup)
│   │   ├── k3s-server/                    ← control-plane install + kubeconfig fetch
│   │   ├── k3s-agent/                     ← data node join
│   │   └── k8s-node-config/               ← labels · taints · local-path · ingress
│   ├── playbooks/
│   │   ├── 00-preflight.yml               ← OS/RAM/disk checks, no changes
│   │   ├── 01-base-setup.yml              ← system config (all nodes)
│   │   ├── 02-k3s-cluster.yml             ← k3s install (Proxmox/local only)
│   │   ├── 03-cloud-node-config.yml       ← sysctl on GKE/EKS/AKS nodes
│   │   └── 04-deploy-platform.yml         ← kustomize build + kubectl apply
│   └── inventories/
│       ├── proxmox/                       ← static inventory (fill IPs manually)
│       ├── gcp/                           ← dynamic via google.cloud.gcp_compute
│       ├── aws/                           ← dynamic via amazon.aws.aws_ec2
│       └── azure/                         ← dynamic via azure.azcollection.azure_rm
│
├── docker/                                ← Local dev stack (no Kubernetes needed)
│   ├── docker-compose.yml                 ← Full stack single-node
│   ├── logstash/                          ← Pipeline config
│   └── hadoop/                            ← Dev XML configs (replication=1, no HA)
│
├── docs/
│   └── starter_guide.docx                 ← Beginner guide (FR): K8s · OpenSearch · Hadoop · Terraform
│
├── scripts/
│   ├── create-secrets.sh                  ← Inject password as k8s Secret
│   └── deploy.sh [gcp|aws|azure|local]    ← Ordered full-stack deploy
│
├── .github/workflows/ci.yml               ← 5-job CI pipeline
├── .env.example
└── .gitignore
```

---

## Getting started

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| `kubectl` | >= 1.28 | [docs](https://kubernetes.io/docs/tasks/tools/) |
| `terraform` | >= 1.7 | [docs](https://developer.hashicorp.com/terraform/install) |
| `kustomize` | >= 5.0 | [docs](https://kubectl.docs.kubernetes.io/installation/kustomize/) |
| `ansible` | >= 2.16 | `pip install ansible` |
| Cloud CLI | latest | `gcloud` / `aws` / `az` |

### Step 1 — Provision the cluster

<details>
<summary><b>GCP (GKE)</b></summary>

```bash
cd terraform/modules/gcp-gke
cp ../../environments/example-gcp.tfvars prod.tfvars
# Edit prod.tfvars: set project_id and region

export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
terraform init
terraform apply -var-file=prod.tfvars

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
terraform init && terraform apply -var-file=prod.tfvars

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
<summary><b>Local / Proxmox (k3s via Ansible)</b></summary>

```bash
# 1. Terraform provisions the VMs only
cd terraform/modules/local-k3s
terraform init && terraform apply -var-file=../../environments/example-local.tfvars

# 2. Ansible installs and configures everything else
cd ansible/
ansible-galaxy collection install -r requirements.yml

# Edit inventories/proxmox/hosts.yml with your VM IPs
ansible-playbook -i inventories/proxmox/ playbooks/00-preflight.yml  # check only
ansible-playbook -i inventories/proxmox/ playbooks/01-base-setup.yml # sysctl + containerd
ansible-playbook -i inventories/proxmox/ playbooks/02-k3s-cluster.yml # k3s + labels

# kubeconfig is fetched automatically to repo root
export KUBECONFIG=$(pwd)/../kubeconfig-server-0.yaml
```
</details>

### Step 2 — Create secrets

```bash
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

# OpenSearch health
kubectl -n data-platform port-forward svc/opensearch 9200:9200 &
curl -u admin:YourStr0ng!Pass1 https://localhost:9200/_cluster/health?pretty -k

# Dashboards  ->  http://localhost:5601
kubectl -n data-platform port-forward svc/opensearch-dashboards 5601:5601 &

# HDFS UI     ->  http://localhost:9870
kubectl -n data-platform port-forward svc/hdfs-namenode 9870:9870 &

# YARN UI     ->  http://localhost:8088
kubectl -n data-platform port-forward svc/yarn-resourcemanager 8088:8088 &
```

---

## Local dev (Docker)

Test the full stack locally without any Kubernetes cluster:

```bash
cp .env.example .env
# Edit .env: set OPENSEARCH_INITIAL_ADMIN_PASSWORD

make dev
make dev-logs
```

| UI | URL |
|---|---|
| OpenSearch Dashboards | http://localhost:5601 |
| OpenSearch API | http://localhost:9200 (Docker dev — HTTP) |
| HDFS NameNode | http://localhost:9870 |
| YARN ResourceManager | http://localhost:8088 |

Differences vs production:

| | Docker (dev) | Kubernetes (prod) |
|---|---|---|
| OpenSearch | 1 node, single-node discovery | 3 master + 3 data + 2 coordinator |
| HDFS | 1 NameNode, replication=1 | 2 NameNodes HA + 3 JournalNodes |
| YARN | 1 ResourceManager | 2 ResourceManagers HA |
| JVM heap | 512MB per service | 1–4GB per role |

---

## Configuration

| Variable | Default | Description |
|---|:---:|---|
| `OPENSEARCH_VERSION` | `2.17.0` | OpenSearch + Dashboards image tag |
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | — | k8s Secret only — never in files |
| `PROVIDER` | `gcp` | Active overlay: `gcp` / `aws` / `azure` / `local` |
| `K8S_NAMESPACE` | `data-platform` | Kubernetes namespace |
| `LOGSTASH_VERSION` | `8.9.0` | Docker dev only |

---

## Operations

### Scale nodes

```bash
kubectl -n data-platform scale statefulset opensearch-data --replicas=5
kubectl -n data-platform scale statefulset hdfs-datanode --replicas=5
```

### Rolling upgrade — OpenSearch

```bash
# Data nodes first, then masters, then coordinator
kubectl -n data-platform set image statefulset/opensearch-data \
  opensearch=opensearchproject/opensearch:2.18.0
kubectl -n data-platform rollout status statefulset/opensearch-data --timeout=300s
```

### Cluster health checks

```bash
# OpenSearch
curl -u admin:$PASS https://localhost:9200/_cluster/health?pretty -k  # K8s : TLS activé

# HDFS — which NameNode is active?
kubectl -n data-platform exec hdfs-namenode-0 -- hdfs haadmin -getServiceState nn0
kubectl -n data-platform exec hdfs-namenode-0 -- hdfs haadmin -getServiceState nn1

# YARN — which ResourceManager is active?
kubectl -n data-platform exec yarn-resourcemanager-0 -- yarn rmadmin -getServiceState rm0
```

---

## Security

| Control | Status | Notes |
|---|:---:|---|
| Passwords stored as k8s Secrets | yes | Never in manifests or git |
| Cloud credentials via ADC / env vars | yes | No credentials files committed |
| OpenSearch auth + RBAC | yes | Built-in security plugin — no X-Pack |
| Pods run as non-root | yes | `runAsUser: 1000`, `fsGroup: 1000` |
| PodDisruptionBudgets | yes | Prevents mass eviction during maintenance |
| Anti-affinity rules | yes | Master/data pods spread across nodes |
| Probes use real password | yes | Exec probes with `$OPENSEARCH_INITIAL_ADMIN_PASSWORD` |
| TLS — HTTPS end-to-end (OpenSearch) | yes | cert-manager PKI interne + `make bootstrap-cert-manager ARGS=--opensearch-pki` |
| Kubernetes NetworkPolicies | yes | Default-deny + allow-list par composant (`network-policies/`) |
| Remote Terraform state | yes | `make bootstrap-backend PROVIDER=gcp` — backends GCS/S3/Azure/HTTP |

---

## CI/CD

Every push and pull request triggers:

| Job | Tool | Checks |
|---|---|---|
| `secret-scan` | Gitleaks | No secrets anywhere in git history |
| `no-hardcoded-secrets` | grep | No weak passwords in YAML / scripts |
| `shellcheck` | ShellCheck | All bash scripts syntactically valid |
| `kube-validate` | kubeconform | All manifests valid against Kubernetes 1.30 |
| `kustomize-build` | kustomize | All 4 overlays build without errors |
| `terraform-validate` | Terraform | `fmt` + `validate` on all 4 modules |
| `checksums-validate` | bash | Ansible SHA256 checksums non-vides et distincts |
| `domain-placeholder-check` | grep | Pas de domaine hardcodé dans l'Ingress base |
| `trivy-scan` | Trivy | CVE CRITICAL/HIGH sur les 5 images Docker |

---

## Roadmap

This repo covers the infrastructure layer. The next phases:

- [ ] Ingestion layer — pluggable scrapers (Scrapy / Playwright) writing to HDFS via Logstash
- [ ] Processing layer — Apache Spark jobs on YARN for cleaning, deduplication, embedding
- [ ] ML layer — MLflow for experiment tracking, DVC for dataset versioning
- [ ] Model serving — API layer connecting to OpenSearch for inference-time retrieval

---

## Documentation

| Document | Description |
|---|---|
| [`docs/starter_guide.docx`](docs/starter_guide.docx) | Beginner guide (FR) — Kubernetes, OpenSearch, Hadoop HDFS/YARN, Terraform |
| [`ansible/README.md`](ansible/README.md) | Ansible workflow — all playbooks and inventory setup |
| [`docker/README.md`](docker/README.md) | Docker Compose local dev guide |

---

## Contributing

1. Fork and branch: `git checkout -b feat/my-feature`
2. Validate locally: `terraform fmt` · `kustomize build k8s/overlays/local` · `make validate`
3. Push and open a PR — all 5 CI jobs must pass before merge

---

<div align="center">

<br/>

Built with OpenSearch · Apache Hadoop · Kubernetes · Terraform · Ansible · Docker

<br/>

![Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-22C55E)

<br/>

</div>
