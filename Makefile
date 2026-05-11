# ══════════════════════════════════════════════════════════════════════════════
# Makefile — single entry point for infrastructure
# ══════════════════════════════════════════════════════════════════════════════
.PHONY: dev dev-down dev-logs validate lint secret secret-tls \
        deploy provision configure upgrade teardown check status help \
        bootstrap-backend bootstrap-cert-manager configure-domain checksums setup sync-configs \
        app-install app-format app-lint app-typecheck app-test app-security app-dev \
        app-bootstrap-indexes app-ingest-mock app-run-pipeline app-search-demo app-e2e

ifneq (,$(wildcard .env))
include .env
endif
PROVIDER  ?= $(or $(PROVIDER),local)
NS        := data-platform
COMPOSE   := docker compose -f docker/docker-compose.yml
APP_COMPOSE := docker compose -f docker/docker-compose.apps.yml
APP_PYTHON := PYTHONPATH=.:apps/api:libs/diagnostik_common .venv/bin/python
APP_PIP := .venv/bin/python -m pip

# ── Setup initial (permissions) ───────────────────────────────────────────────
## Restore executable permissions on scripts (after git clone or unzip)
## Run once: make setup
setup:
	@find scripts/ -name "*.sh" -exec chmod +x {} \;
	@echo "✓ Permissions +x restored on scripts."


## Sync config files into k8s/base/ from their sources
## (config/* et scripts/) — kustomize only accepts files
## in the kustomization directory or below.
## Run after any modification to config/ or scripts/fence-namenode.sh
sync-configs:
	@cp config/logstash/logstash.yml  k8s/base/config/logstash/logstash.yml
	@cp config/logstash/pipeline.conf k8s/base/config/logstash/pipeline.conf
	@cp config/kafka/server.properties k8s/base/config/kafka/server.properties
	@cp config/spark/spark-defaults.conf k8s/base/config/spark/spark-defaults.conf
	@cp scripts/fence-namenode.sh     k8s/base/scripts/fence-namenode.sh
	@echo "✓ Configs synced to k8s/base/"


# ── Dev local (Docker Compose) ────────────────────────────────────────────────

dev: .env
	@echo "==> Stack dev (Docker Compose)..."
	$(COMPOSE) up -d
	@echo ""
	@echo "  Dashboards  → http://localhost:5601"
	@echo "  OpenSearch  → http://localhost:9200"
	@echo "  Kafka       → 127.0.0.1:9092"
	@echo "  Spark UI    → http://localhost:18081"
	@echo "  HDFS UI     → http://localhost:9870"
	@echo "  YARN UI     → http://localhost:8088"

dev-down:
	$(COMPOSE) down -v

dev-logs:
	$(COMPOSE) logs -f

.env:
	@echo "ERROR: .env missing. Run:  cp .env.example .env"
	@exit 1

# ── Diagnostik Community App ────────────────────────────────────────────────

app-install:
	@python3 -m venv .venv
	@$(APP_PIP) install --upgrade pip
	@$(APP_PIP) install -e libs/diagnostik_common -e "apps/api[dev]" -e apps/worker

app-format:
	@.venv/bin/ruff format apps libs connectors scripts tests

app-lint:
	@$(APP_PYTHON) -m ruff check apps libs connectors scripts tests

app-typecheck:
	@$(APP_PYTHON) -m mypy apps/api/app libs/diagnostik_common/diagnostik_common connectors/mock

app-test:
	@$(APP_PYTHON) -m pytest apps/api/tests libs/diagnostik_common/tests connectors/mock/tests tests/integration

app-security:
	@echo "Run pip-audit, bandit, trivy and gitleaks in CI-enabled environments."

app-dev: .env
	@$(APP_COMPOSE) up --build

app-bootstrap-indexes:
	@$(APP_PYTHON) scripts/bootstrap_indexes.py

app-ingest-mock:
	@$(APP_PYTHON) scripts/app_ingest_mock.py

app-run-pipeline:
	@$(APP_PYTHON) scripts/app_run_pipeline.py

app-search-demo:
	@$(APP_PYTHON) scripts/app_search_demo.py

app-e2e: app-bootstrap-indexes app-ingest-mock app-run-pipeline app-search-demo
	@echo "✓ App E2E flow completed."

# ── Secrets K8s ───────────────────────────────────────────────────────────────

## Credentials OpenSearch (obligatoire avant make deploy)
secret: .env
	@bash scripts/create-secrets.sh

## Self-signed TLS certificates for OpenSearch (dev K8s)
## En prod : utiliser cert-manager — voir k8s/base/cert-manager/cluster-issuer.yaml
secret-tls:
	@bash scripts/generate-certs-dev.sh

# ── Full deployment ───────────────────────────────────────────────────────

deploy: secret
	@echo "==> Deployment — provider: $(PROVIDER)"
	@bash scripts/deploy.sh $(PROVIDER)

provision:
	@bash scripts/provision.sh $(PROVIDER)

configure:
	@ansible-playbook \
	  -i ansible/inventories/$(PROVIDER)/hosts.yml \
	  ansible/playbooks/00-preflight.yml \
	  ansible/playbooks/01-base-setup.yml \
	  ansible/playbooks/02-k3s-cluster.yml \
	  ansible/playbooks/03-cloud-node-config.yml \
	  ansible/playbooks/04-deploy-platform.yml

# ── Upgrade versions ──────────────────────────────────────────────────────────
## Synchronise les versions dans .env.example ET kustomization.yaml en une commande.
## Usage : make upgrade VERSION_OS=2.18.0
##         make upgrade VERSION_OS=2.18.0 VERSION_LS=8.10.0 VERSION_HADOOP=3.4.0
# ── macOS / Linux portability ─────────────────────────────────────────────────
# sed -i differs: Linux = sed -i, macOS = sed -i ''
SED_I := $(shell uname -s | grep -qi darwin && echo "sed -i ''" || echo "sed -i")

upgrade:
	@if [ -z "$(VERSION_OS)$(VERSION_LS)$(VERSION_HADOOP)" ]; then \
	  echo "Usage: make upgrade VERSION_OS=X.Y.Z [VERSION_LS=X.Y.Z] [VERSION_HADOOP=X.Y.Z]"; \
	  echo "Versions currentles :"; \
	  grep "^OPENSEARCH_VERSION\|^LOGSTASH_VERSION\|^HADOOP_VERSION" .env.example; \
	  exit 0; \
	fi
	@echo "==> Updating versions..."
	@if [ -n "$(VERSION_OS)" ]; then \
	  $(SED_I) "s/^OPENSEARCH_VERSION=.*/OPENSEARCH_VERSION=$(VERSION_OS)/" .env.example; \
	  $(SED_I) "s|newTag: \"[0-9.]*\"  # opensearch|newTag: \"$(VERSION_OS)\"  # opensearch|g" k8s/base/kustomization.yaml; \
	  $(SED_I) "/name: opensearchproject\/opensearch$$/{ n; s/newTag:.*/newTag: \"$(VERSION_OS)\"/; }" k8s/base/kustomization.yaml; \
	  $(SED_I) "/name: opensearchproject\/opensearch-dashboards$$/{n; s/newTag:.*/newTag: \"$(VERSION_OS)\"/; }" k8s/base/kustomization.yaml; \
	  echo "  OpenSearch → $(VERSION_OS)"; \
	fi
	@if [ -n "$(VERSION_LS)" ]; then \
	  $(SED_I) "s/^LOGSTASH_VERSION=.*/LOGSTASH_VERSION=$(VERSION_LS)/" .env.example; \
	  $(SED_I) "/name: opensearchproject\/logstash.*/{n; s/newTag:.*/newTag: \"$(VERSION_LS)\"/; }" k8s/base/kustomization.yaml; \
	  echo "  Logstash   → $(VERSION_LS)"; \
	fi
	@if [ -n "$(VERSION_HADOOP)" ]; then \
	  $(SED_I) "s/^HADOOP_VERSION=.*/HADOOP_VERSION=$(VERSION_HADOOP)/" .env.example; \
	  $(SED_I) "/name: apache\/hadoop$$/{n; s/newTag:.*/newTag: \"$(VERSION_HADOOP)\"/; }" k8s/base/kustomization.yaml; \
	  echo "  Hadoop     → $(VERSION_HADOOP)"; \
	fi
	@echo ""
	@echo "  Versions synced in .env.example and kustomization.yaml."
	@echo "  Validate: make validate   Deploy: make deploy"

# ── Teardown ─────────────────────────────────────────────────────────────
## Supprime toutes les ressources K8s du namespace (DESTRUCTIF)
teardown:
	@echo "WARNING: deleting ALL resources in $(NS) (IRREVERSIBLE)"
	@printf "Taper YES pour confirmer : " && read CONFIRM && [ "$$CONFIRM" = "YES" ] || exit 1
	@echo "==> Suppression des workloads..."
	kubectl -n $(NS) delete all --all --ignore-not-found
	@echo "==> Suppression des PVCs..."
	kubectl -n $(NS) delete pvc --all --ignore-not-found
	@echo "==> Suppression des ConfigMaps..."
	kubectl -n $(NS) delete configmap --all --ignore-not-found
	@echo "==> Suppression des Secrets..."
	kubectl -n $(NS) delete secret --all --ignore-not-found
	@echo "==> Suppression des NetworkPolicies..."
	kubectl -n $(NS) delete networkpolicy --all --ignore-not-found
	@echo "==> Suppression des PodDisruptionBudgets..."
	kubectl -n $(NS) delete pdb --all --ignore-not-found
	@echo "==> Suppression des Ingress..."
	kubectl -n $(NS) delete ingress --all --ignore-not-found
	@echo "==> Suppression du namespace..."
	kubectl delete namespace $(NS) --ignore-not-found
	@echo "✓ Namespace $(NS) and all its resources deleted."

# ── Bootstrap infrastructure ──────────────────────────────────────────────────

## Initialize Terraform remote state (GCS / S3 / Azure Blob / HTTP)
## Usage : PROVIDER=gcp PROJECT_ID=my-project REGION=eu-west1 make bootstrap-backend
bootstrap-backend:
	@bash scripts/bootstrap-backend.sh $(PROVIDER) $(ARGS)

## Install cert-manager + ClusterIssuer on the current cluster
## Usage : ACME_EMAIL=ops@mycompany.com make bootstrap-cert-manager
## With OpenSearch PKI (recommended prod) : make bootstrap-cert-manager ARGS=--opensearch-pki
## Staging + PKI : make bootstrap-cert-manager ARGS="--staging --opensearch-pki"
bootstrap-cert-manager:
	@bash scripts/bootstrap-cert-manager.sh "$${ACME_EMAIL:-}" $(ARGS)

## Configure Ingress domain (generates patches/ingress-domain.yaml)
## Usage : PROVIDER=gcp DOMAIN=mycompany.com ACME_EMAIL=ops@mycompany.com make configure-domain
configure-domain:
	@bash scripts/configure-domain.sh $(PROVIDER) "$${DOMAIN:-}" "$${ACME_EMAIL:-}"

## Recalculate SHA256 hashes of Ansible manifests (local-path-provisioner + ingress-nginx)
## Run after any version change in ansible/roles/k8s-node-config/vars/main.yml
checksums:
	@bash scripts/update-checksums.sh


# ── Validation ────────────────────────────────────────────────────────────────

validate: lint
	@for m in gcp-gke aws-eks azure-aks local-k3s; do \
	  terraform -chdir=terraform/modules/$$m fmt -check || exit 1; \
	done
	@echo "✓ Validation complete."

lint:
	@find k8s/base -name "*.yaml" \
	  ! -name "*secret*" ! -name "kustomization*" ! -name "network-policies*" \
	  ! -name "cluster-issuer*" \
	  | xargs kubeconform -kubernetes-version 1.30.0 -strict -ignore-missing-schemas -summary
	@for ov in gcp aws azure local; do \
	  kustomize build k8s/overlays/$$ov > /dev/null && echo "  overlay $$ov ✓"; \
	done

# ── Checking prerequisites ────────────────────────────────────────────────
## Checks that all required tools are installed before deploy
check:
	@echo "==> Checking prerequisites (universal)..."
	@MISSING=0; \
	for tool in kubectl kustomize terraform ansible openssl curl jq; do \
	  if ! command -v $$tool &>/dev/null; then \
	    echo "  ✗ $$tool manquant"; MISSING=1; \
	  else \
	    echo "  ✓ $$($$tool version 2>/dev/null | head -1 || $$tool --version 2>/dev/null | head -1 || echo $$tool)"; \
	  fi; \
	done
	@echo ""
	@echo "==> Checking provider-specific CLIs (PROVIDER=$(PROVIDER))..."
	@case "$(PROVIDER)" in \
	  gcp)   CLI=gsutil ;; \
	  aws)   CLI=aws    ;; \
	  azure) CLI=az     ;; \
	  local) CLI=""     ;; \
	  *) CLI="" ;; \
	esac; \
	if [ -n "$$CLI" ]; then \
	  if ! command -v $$CLI &>/dev/null; then \
	    echo "  ✗ $$CLI manquant (required for PROVIDER=$(PROVIDER))"; MISSING=1; \
	  else \
	    echo "  ✓ $$CLI available"; \
	  fi; \
	fi
	@[ "$$MISSING" -eq 0 ] && echo "" && echo "✓ All prerequisites are satisfied." || \
	  (echo "" && echo "✗ Install missing tools before continuing." && exit 1)


# ── Statut ────────────────────────────────────────────────────────────────────

status:
	kubectl -n $(NS) get pods -o wide

# ── Aide ──────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  diagnostix"
	@echo ""
	@echo "  Dev local (Docker, sans Kubernetes)"
	@echo "    make dev                      Start the stack"
	@echo "    make dev-logs                 Suivre les logs"
	@echo "    make dev-down                 Stop + remove volumes"
	@echo ""
	@echo "  Secrets & TLS"
	@echo "    make secret                   Create opensearch-credentials Secret"
	@echo "    make secret-tls               Generate self-signed TLS certs (dev K8s)"
	@echo "    make bootstrap-cert-manager ARGS=--opensearch-pki   PKI OpenSearch prod"
	@echo ""
	@echo "  Kubernetes (cloud ou on-prem)"
	@echo "    make deploy [PROVIDER=x]      Full deployment  (default: $(PROVIDER))"
	@echo "    make provision [PROVIDER=x]   Terraform apply seulement (scripts/provision.sh)"
	@echo "    make configure [PROVIDER=x]   Ansible seulement"
	@echo "    make teardown                 Supprimer toutes les ressources (DESTRUCTIF)"
	@echo "    make status                   Status des pods"
	@echo ""
	@echo "  Versions"
	@echo "    make upgrade VERSION_OS=2.18.0           Synchronise .env + kustomization.yaml"
	@echo "    make upgrade VERSION_OS=2.18.0 VERSION_LS=8.10.0 VERSION_HADOOP=3.4.0"
	@echo ""
	@echo "  Prerequisites"
	@echo "    make setup                    Restore +x on scripts (once after clone)"
	@echo "    make check                    Check installed tools"
	@echo ""
	@echo "  CI / validation"
	@echo "    make validate                 kubeconform + kustomize + terraform fmt"
	@echo "    make lint                     kubeconform + kustomize build"
	@echo "    make app-test                 Run community app unit tests"
	@echo ""
	@echo "  Provider : PROVIDER=gcp|aws|azure|local  (current: $(PROVIDER))"
	@echo ""
	@echo "  Bootstrap infrastructure (une fois par cluster)"
	@echo "    make bootstrap-backend   PROVIDER=gcp PROJECT_ID=...  Init remote state"
	@echo "    make configure-domain    PROVIDER=gcp DOMAIN=...      Configure Ingress domain"
	@echo "    make bootstrap-cert-manager  ACME_EMAIL=...           Install cert-manager"
	@echo "    make checksums                                         Recalculate Ansible SHA256"
	@echo ""
