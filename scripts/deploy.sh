#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# deploy.sh — full deployment via kustomize
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/deploy.sh [PROVIDER]
#         PROVIDER : gcp | aws | azure | local  (default: gcp)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── DRY-1/SOLID-D : shared lib ───────────────────────────────────────────
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh not found"; exit 1; }
ensure_repo_root

load_env
PROVIDER="${1:-${PROVIDER:-gcp}}"
NS="data-platform"
OVERLAY="k8s/overlays/${PROVIDER}"

# ── Validation provider (SOLID-S) ─────────────────────────────────────────────
validate_provider "${PROVIDER}" || exit 1

if [[ ! -d "${OVERLAY}" ]]; then
  log_err "Overlay not found : ${OVERLAY}"
  exit 1
fi

# ── [1] Namespace ──────────────────────────────────────────────────────────────
log_step "[1/8] Namespace..."
kubectl apply -f k8s/base/namespace/namespace.yaml

# ── [2] Secrets ────────────────────────────────────────────────────────────────
if ! kubectl -n "${NS}" get secret opensearch-credentials &>/dev/null; then
  log_err "Secret 'opensearch-credentials' not found. Create with : make secret"
  exit 1
fi
log_info "[2/8] opensearch-credentials ✓"

if ! kubectl -n "${NS}" get secret opensearch-tls-certs &>/dev/null; then
  log_err "Secret 'opensearch-tls-certs' not found. Create with : make secret-tls"
  exit 1
fi
log_info "[2b] opensearch-tls-certs ✓"

# ── [3] cert-manager (cloud only — SOLID-L provider capabilities) ─────
if provider_has_certmanager "${PROVIDER}"; then
  if kubectl get namespace cert-manager &>/dev/null && \
     kubectl -n cert-manager get deploy cert-manager &>/dev/null 2>/dev/null; then
    log_info "[3/8] cert-manager ✓ (already installed)"
  else
    log_warn "[3/8] cert-manager not installed — Ingress TLS disabled"
    log_warn "  To enable : make bootstrap-cert-manager ACME_EMAIL=ops@domain.com ARGS=--staging"
  fi
else
  log_info "[3/8] cert-manager non requis (provider ${PROVIDER})"
fi

# ── [4] Domain Ingress (cloud uniquement) ─────────────────────────────────────
if provider_has_dns_ingress "${PROVIDER}"; then
  DOMAIN_PATCH="${OVERLAY}/patches/ingress-domain.yaml"
  if [[ -f "${DOMAIN_PATCH}" ]]; then
    log_info "[4/8] Ingress domain ✓ (patch present)"
  else
    log_warn "[4/8] Domain patch missing — Ingress garde REPLACE_WITH_YOUR_DOMAIN"
    log_warn "  Configurer : make configure-domain DOMAIN=... ACME_EMAIL=..."
  fi
else
  log_info "[4/8] Ingress DNS non requis (port-forward pour provider ${PROVIDER})"
fi

# ── [5] Deploy overlay kustomize ───────────────────────────────────────────────
log_step "[5/8] Applying kustomize overlay : ${PROVIDER}..."
kustomize build "${OVERLAY}" | kubectl apply -f -

# ── [6-8] Attente des workloads (DRY-3 — factorisation wait_rollout) ──────────
log_step "[6/8] Waiting for HDFS dependencies..."
wait_rollout statefulset/zookeeper       180
wait_rollout statefulset/hdfs-journalnode 180

log_step "[7/8] Waiting for HDFS + YARN..."
wait_rollout statefulset/hdfs-namenode        300
wait_rollout statefulset/yarn-resourcemanager  180

log_step "[8/8] Waiting for OpenSearch..."
wait_rollout statefulset/opensearch-master 300

# ── Summary ────────────────────────────────────────────────────────────────────
DOMAIN_CONFIGURED="${DOMAIN:-REPLACE_WITH_YOUR_DOMAIN}"
echo ""
log_done "Deployment complete — provider : ${PROVIDER}"
echo ""
if provider_has_dns_ingress "${PROVIDER}" && [[ -f "${OVERLAY}/patches/ingress-domain.yaml" ]]; then
  echo "  Dashboards  → https://dashboards.${DOMAIN_CONFIGURED}"
  echo "  YARN UI     → https://yarn.${DOMAIN_CONFIGURED}"
  echo "  HDFS UI     → https://hdfs.${DOMAIN_CONFIGURED}"
else
  echo "  Dashboards  : kubectl -n ${NS} port-forward svc/opensearch-dashboards 5601:5601"
  echo "  HDFS UI     : kubectl -n ${NS} port-forward svc/hdfs-namenode 9870:9870"
  echo "  YARN UI     : kubectl -n ${NS} port-forward svc/yarn-resourcemanager 8088:8088"
fi
echo ""
echo "  Status : make status"
echo ""
