# ══════════════════════════════════════════════════════════════════════════════
# Makefile — point d'entrée unique de l'infrastructure
# ══════════════════════════════════════════════════════════════════════════════
.PHONY: dev dev-down dev-logs validate lint secret secret-tls \
        deploy provision configure upgrade teardown check status help \
        bootstrap-backend bootstrap-cert-manager configure-domain checksums setup

-include .env
PROVIDER  ?= $(or $(PROVIDER),local)
NS        := data-platform
COMPOSE   := docker compose -f docker/docker-compose.yml

# ── Setup initial (permissions) ───────────────────────────────────────────────
## Restaure les permissions exécutables sur les scripts (après git clone ou unzip)
## Exécuter une seule fois : make setup
setup:
	@find scripts/ -name "*.sh" -exec chmod +x {} \;
	@echo "✓ Permissions +x restaurées sur les scripts."


# ── Dev local (Docker Compose) ────────────────────────────────────────────────

dev: .env
	@echo "==> Stack dev (Docker Compose)..."
	$(COMPOSE) up -d
	@echo ""
	@echo "  Dashboards  → http://localhost:5601"
	@echo "  OpenSearch  → http://localhost:9200"
	@echo "  HDFS UI     → http://localhost:9870"
	@echo "  YARN UI     → http://localhost:8088"

dev-down:
	$(COMPOSE) down -v

dev-logs:
	$(COMPOSE) logs -f

.env:
	@echo "ERREUR : .env manquant. Exécuter :  cp .env.example .env"
	@exit 1

# ── Secrets K8s ───────────────────────────────────────────────────────────────

## Credentials OpenSearch (obligatoire avant make deploy)
secret: .env
	@bash scripts/create-secrets.sh

## Certificats TLS auto-signés pour OpenSearch (dev K8s)
## En prod : utiliser cert-manager — voir k8s/base/cert-manager/cluster-issuer.yaml
secret-tls:
	@bash scripts/generate-certs-dev.sh

# ── Déploiement complet ───────────────────────────────────────────────────────

deploy: secret
	@echo "==> Déploiement — provider: $(PROVIDER)"
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
# ── Portabilité macOS / Linux ─────────────────────────────────────────────────
# sed -i diffère : Linux = sed -i, macOS = sed -i ''
SED_I := $(shell uname -s | grep -qi darwin && echo "sed -i ''" || echo "sed -i")

upgrade:
	@if [ -z "$(VERSION_OS)$(VERSION_LS)$(VERSION_HADOOP)" ]; then \
	  echo "Usage: make upgrade VERSION_OS=X.Y.Z [VERSION_LS=X.Y.Z] [VERSION_HADOOP=X.Y.Z]"; \
	  echo "Versions actuelles :"; \
	  grep "^OPENSEARCH_VERSION\|^LOGSTASH_VERSION\|^HADOOP_VERSION" .env.example; \
	  exit 0; \
	fi
	@echo "==> Mise à jour des versions..."
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
	@echo "  Versions synchronisées dans .env.example et kustomization.yaml."
	@echo "  Valider : make validate   Déployer : make deploy"

# ── Démantèlement ─────────────────────────────────────────────────────────────
## Supprime toutes les ressources K8s du namespace (DESTRUCTIF)
teardown:
	@echo "ATTENTION : suppression de TOUTES les ressources dans $(NS) (IRRÉVERSIBLE)"
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
	@echo "✓ Namespace $(NS) et toutes ses ressources supprimés."

# ── Bootstrap infrastructure ──────────────────────────────────────────────────

## Initialise le remote state Terraform (GCS / S3 / Azure Blob / HTTP)
## Usage : PROVIDER=gcp PROJECT_ID=my-project REGION=eu-west1 make bootstrap-backend
bootstrap-backend:
	@bash scripts/bootstrap-backend.sh $(PROVIDER) $(ARGS)

## Installe cert-manager + ClusterIssuer sur le cluster courant
## Usage : ACME_EMAIL=ops@mycompany.com make bootstrap-cert-manager
## Avec PKI OpenSearch (recommandé prod) : make bootstrap-cert-manager ARGS=--opensearch-pki
## Staging + PKI : make bootstrap-cert-manager ARGS="--staging --opensearch-pki"
bootstrap-cert-manager:
	@bash scripts/bootstrap-cert-manager.sh "$${ACME_EMAIL:-}" $(ARGS)

## Configure le domaine Ingress (génère patches/ingress-domain.yaml)
## Usage : PROVIDER=gcp DOMAIN=mycompany.com ACME_EMAIL=ops@mycompany.com make configure-domain
configure-domain:
	@bash scripts/configure-domain.sh $(PROVIDER) "$${DOMAIN:-}" "$${ACME_EMAIL:-}"

## Recalcule les SHA256 des manifests Ansible (local-path-provisioner + ingress-nginx)
## Exécuter après tout changement de version dans ansible/roles/k8s-node-config/vars/main.yml
checksums:
	@bash scripts/update-checksums.sh


# ── Validation ────────────────────────────────────────────────────────────────

validate: lint
	@for m in gcp-gke aws-eks azure-aks local-k3s; do \
	  terraform -chdir=terraform/modules/$$m fmt -check || exit 1; \
	done
	@echo "✓ Validation complète."

lint:
	@find k8s/base -name "*.yaml" \
	  ! -name "*secret*" ! -name "kustomization*" ! -name "network-policies*" \
	  ! -name "cluster-issuer*" \
	  | xargs kubeconform -kubernetes-version 1.30.0 -strict -ignore-missing-schemas -summary
	@for ov in gcp aws azure local; do \
	  kustomize build k8s/overlays/$$ov > /dev/null && echo "  overlay $$ov ✓"; \
	done

# ── Vérification des prérequis ────────────────────────────────────────────────
## Vérifie que tous les outils requis sont installés avant deploy
check:
	@echo "==> Vérification des prérequis (universels)..."
	@MISSING=0; \
	for tool in kubectl kustomize terraform ansible openssl curl jq; do \
	  if ! command -v $$tool &>/dev/null; then \
	    echo "  ✗ $$tool manquant"; MISSING=1; \
	  else \
	    echo "  ✓ $$($$tool version 2>/dev/null | head -1 || $$tool --version 2>/dev/null | head -1 || echo $$tool)"; \
	  fi; \
	done
	@echo ""
	@echo "==> Vérification des CLI provider-spécifiques (PROVIDER=$(PROVIDER))..."
	@case "$(PROVIDER)" in \
	  gcp)   CLI=gsutil ;; \
	  aws)   CLI=aws    ;; \
	  azure) CLI=az     ;; \
	  local) CLI=""     ;; \
	  *) CLI="" ;; \
	esac; \
	if [ -n "$$CLI" ]; then \
	  if ! command -v $$CLI &>/dev/null; then \
	    echo "  ✗ $$CLI manquant (requis pour PROVIDER=$(PROVIDER))"; MISSING=1; \
	  else \
	    echo "  ✓ $$CLI disponible"; \
	  fi; \
	fi
	@[ "$$MISSING" -eq 0 ] && echo "" && echo "✓ Tous les prérequis sont satisfaits." || \
	  (echo "" && echo "✗ Installer les outils manquants avant de continuer." && exit 1)


# ── Statut ────────────────────────────────────────────────────────────────────

status:
	kubectl -n $(NS) get pods -o wide

# ── Aide ──────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  infrastructure-resiliente"
	@echo ""
	@echo "  Dev local (Docker, sans Kubernetes)"
	@echo "    make dev                      Démarrer la stack"
	@echo "    make dev-logs                 Suivre les logs"
	@echo "    make dev-down                 Arrêter + supprimer volumes"
	@echo ""
	@echo "  Secrets & TLS"
	@echo "    make secret                   Créer Secret opensearch-credentials"
	@echo "    make secret-tls               Générer certs TLS auto-signés (dev K8s)"
	@echo "    make bootstrap-cert-manager ARGS=--opensearch-pki   PKI OpenSearch prod"
	@echo ""
	@echo "  Kubernetes (cloud ou on-prem)"
	@echo "    make deploy [PROVIDER=x]      Déploiement complet  (défaut: $(PROVIDER))"
	@echo "    make provision [PROVIDER=x]   Terraform apply seulement (scripts/provision.sh)"
	@echo "    make configure [PROVIDER=x]   Ansible seulement"
	@echo "    make teardown                 Supprimer toutes les ressources (DESTRUCTIF)"
	@echo "    make status                   État des pods"
	@echo ""
	@echo "  Versions"
	@echo "    make upgrade VERSION_OS=2.18.0           Synchronise .env + kustomization.yaml"
	@echo "    make upgrade VERSION_OS=2.18.0 VERSION_LS=8.10.0 VERSION_HADOOP=3.4.0"
	@echo ""
	@echo "  Prérequis"
	@echo "    make setup                    Restaurer +x sur les scripts (1 fois après clone)"
	@echo "    make check                    Vérifier les outils installés"
	@echo ""
	@echo "  CI / validation"
	@echo "    make validate                 kubeconform + kustomize + terraform fmt"
	@echo "    make lint                     kubeconform + kustomize build"
	@echo ""
	@echo "  Provider : PROVIDER=gcp|aws|azure|local  (actuel: $(PROVIDER))"
	@echo ""
	@echo "  Bootstrap infrastructure (une fois par cluster)"
	@echo "    make bootstrap-backend   PROVIDER=gcp PROJECT_ID=...  Init remote state"
	@echo "    make configure-domain    PROVIDER=gcp DOMAIN=...      Config domaine Ingress"
	@echo "    make bootstrap-cert-manager  ACME_EMAIL=...           Install cert-manager"
	@echo "    make checksums                                         Recalcul SHA256 Ansible"
	@echo ""
