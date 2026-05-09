#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# bootstrap-cert-manager.sh — installs cert-manager + ClusterIssuer
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/bootstrap-cert-manager.sh [ACME_EMAIL] [--staging]
#
#   ACME_EMAIL : email for Let's Encrypt.
#                Priority: argument > env variable > .env
#   --staging  : use letsencrypt-staging (recommended for testing)
#
# Idempotent — if cert-manager is already installed, skips installation.
# Prerequisites: kubectl configured on the target cluster.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh not found"; exit 1; }
ensure_repo_root

# ── .env loading — ONCE via load_env (FIX B1) ───────────────────
load_env

# ── Versions — overridable from .env (FIX B4) ─────────────────────────────
CERTMANAGER_VERSION="${CERTMANAGER_VERSION:-v1.16.2}"
CERTMANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml"
CERTMANAGER_SHA256="${CERTMANAGER_SHA256:-}"   # FIX B4 : empty by default, override via .env

# ── Arguments : priority: arg > .env (FIX B1 — correct order) ─────────────────
# load_env has set ACME_EMAIL from .env if present.
# Positional argument $1 (if provided and not --staging) takes priority.
USE_STAGING=false
INSTALL_OPENSEARCH_PKI=false
for arg in "$@"; do
  case "${arg}" in
    --staging)        USE_STAGING=true ;;
    --opensearch-pki) INSTALL_OPENSEARCH_PKI=true ;;
    *)                [[ -n "${arg}" ]] && ACME_EMAIL="${arg}" ;;
  esac
done
ACME_EMAIL="${ACME_EMAIL:-}"

# ACME_EMAIL required for Let's Encrypt — optional in --opensearch-pki-only mode
if [[ -z "${ACME_EMAIL}" ]]; then
  if ${INSTALL_OPENSEARCH_PKI} && ! ${USE_STAGING}; then
    log_warn "ACME_EMAIL absent — Internal OpenSearch PKI only (no Let's Encrypt Ingress)."
  else
    log_err "ACME email required for Let's Encrypt."
    log_err "  Usage : bash scripts/bootstrap-cert-manager.sh ops@mycompany.com"
    log_err "  Ou   : make bootstrap-cert-manager ACME_EMAIL=ops@mycompany.com"
    exit 1
  fi
else
  validate_email "${ACME_EMAIL}" || exit 1
fi

# ── ClusterIssuer — auto-generation if absent ─────────────────────────
CLUSTER_ISSUER_FILE="k8s/base/cert-manager/cluster-issuer-configured.yaml"
if [[ ! -f "${CLUSTER_ISSUER_FILE}" ]]; then
  log_info "ClusterIssuer absent — auto-generating with email ${ACME_EMAIL}..."
  bash scripts/configure-domain.sh "${PROVIDER:-gcp}" "${DOMAIN:-example.com}" "${ACME_EMAIL}" || true
fi

log_step "Bootstrap cert-manager ${CERTMANAGER_VERSION}"
log_info "ACME email : ${ACME_EMAIL}"
if ${USE_STAGING}; then _MODE="STAGING (testing)"; else _MODE="PRODUCTION"; fi
log_info "Mode       : ${_MODE}"

# ── 1. Check if cert-manager is already installed ────────────────────────────
if kubectl get namespace cert-manager &>/dev/null && \
   kubectl -n cert-manager get deploy cert-manager &>/dev/null 2>/dev/null; then
  INSTALLED=$(kubectl -n cert-manager get deploy cert-manager \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null \
    | grep -oP 'v[\d.]+' | head -1 || echo "inconnue")
  log_info "cert-manager already installed (detected version : ${INSTALLED})"
  if [[ "${INSTALLED}" == "${CERTMANAGER_VERSION}" ]]; then
    log_ok "Version up to date — installation skipped"
  else
    log_warn "Version ${INSTALLED} ≠ ${CERTMANAGER_VERSION} — update..."
    kubectl apply -f "${CERTMANAGER_URL}"
  fi
else
  # ── 2. Download + verify ─────────────────────────────────────────────
  TMPDIR="$(mktemp -d)"
  # shellcheck disable=SC2064  # intentional: immediate expansion to capture TMPDIR
  trap "rm -rf ${TMPDIR}" EXIT

  log_info "Downloading cert-manager ${CERTMANAGER_VERSION}..."
  if ! curl -sLf --max-time 60 -o "${TMPDIR}/cert-manager.yaml" "${CERTMANAGER_URL}"; then
    log_err "Unable to download cert-manager : ${CERTMANAGER_URL}"
    exit 1
  fi

  if [[ -n "${CERTMANAGER_SHA256}" ]]; then
    ACTUAL=$(sha256sum "${TMPDIR}/cert-manager.yaml" | cut -d' ' -f1)
    if [[ "${ACTUAL}" != "${CERTMANAGER_SHA256}" ]]; then
      log_err "SHA256 mismatch for cert-manager!"
      log_err "  Expected : ${CERTMANAGER_SHA256}"
      log_err "  Got  : ${ACTUAL}"
      log_err "  Stopping — do not install a compromised manifest."
      exit 1
    fi
    log_ok "SHA256 verified"
  else
    log_warn "SHA256 not verified — override via CERTMANAGER_SHA256 in .env to secure"
  fi

  log_info "Installing cert-manager ${CERTMANAGER_VERSION}..."
  kubectl apply -f "${TMPDIR}/cert-manager.yaml"
  log_ok "Manifest applied"
fi

# ── 3. Waiting for startup — via wait_rollout from lib/common.sh (FIX B3) ─────────
# cert-manager a son propre namespace donc on surcharge NS localement
NS="cert-manager"
log_step "Waiting for cert-manager to start (may take 2-3 min)..."
wait_rollout deploy/cert-manager          300
wait_rollout deploy/cert-manager-webhook  300
wait_rollout deploy/cert-manager-cainjector 300

# ── 4. Attendre que le webhook accepte les CRDs ───────────────────────────────
log_info "Waiting for CRD webhook..."
for i in $(seq 1 20); do
  if kubectl apply --dry-run=client -f /dev/stdin 2>/dev/null << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: test-webhook-ready
spec:
  selfSigned: {}
EOF
  then
    log_ok "Webhook ready"
    break
  fi
  [[ "${i}" -eq 20 ]] && { log_err "Timeout: cert-manager webhook"; exit 1; }
  log_info "Waiting for webhook (${i}/20)..."
  sleep 5
done

# ── 5. Appliquer le ClusterIssuer ─────────────────────────────────────────────
if [[ -f "${CLUSTER_ISSUER_FILE}" ]]; then
  if ${USE_STAGING}; then
    kubectl delete clusterissuer letsencrypt-staging --ignore-not-found || true
  fi
  kubectl apply -f "${CLUSTER_ISSUER_FILE}"
  log_ok "ClusterIssuers applied"
  echo ""
  kubectl get clusterissuer 2>/dev/null || true
else
  log_warn "${CLUSTER_ISSUER_FILE} not found — ClusterIssuer not applied"
  log_warn "  Generate : make configure-domain PROVIDER=... DOMAIN=... ACME_EMAIL=..."
fi

# ── 6. PKI OpenSearch (optionnel : --opensearch-pki) ──────────────────────────
if ${INSTALL_OPENSEARCH_PKI}; then
  log_step "Deploying OpenSearch PKI (CA + Issuer + Certificate)..."
  OPENSEARCH_PKI="k8s/base/cert-manager/opensearch-pki.yaml"
  if [[ ! -f "${OPENSEARCH_PKI}" ]]; then
    log_err "${OPENSEARCH_PKI} not found"
    log_err "  This file must be present in the repository."
    exit 1
  fi
  # C3 : create the namespace before applying namespace-scoped resources
  log_info "Creating data-platform namespace (if missing)..."
  kubectl apply -f k8s/base/namespace/namespace.yaml
  kubectl apply -f "${OPENSEARCH_PKI}"
  log_ok "OpenSearch PKI applied"
  log_info "Note : the opensearch-ca-issuer Issuer may be NotReady for 30-60s while"
  log_info "  cert-manager issues the opensearch-ca-secret Secret. This is normal."

  # Attendre que le Secret opensearch-tls-certs soit created par cert-manager
  log_info "Waiting for opensearch-tls-certs Secret creation..."
  NS="data-platform"
  for i in $(seq 1 30); do
    if kubectl -n "${NS}" get secret opensearch-tls-certs &>/dev/null; then
      log_ok "Secret opensearch-tls-certs created par cert-manager"
      break
    fi
    [[ "${i}" -eq 30 ]] && { log_err "Timeout : opensearch-tls-certs non created"; exit 1; }
    log_info "Waiting for cert-manager (${i}/30)..."
    sleep 10
  done

  echo ""
  log_info "OpenSearch TLS Certificate :"
  kubectl -n "${NS}" get certificate opensearch-tls 2>/dev/null || true
  echo ""
  log_info "Automatic renewal: cert-manager renews 30 days before expiry."
  log_info "To check : kubectl -n ${NS} get certificate,certificaterequest"
fi

log_done "cert-manager bootstrap complete"
echo ""
echo "  cert-manager status :"
kubectl -n cert-manager get pods 2>/dev/null | head -6 || true
echo ""
if ${USE_STAGING}; then
  echo "  ⚠  Mode STAGING — certificats non reconnus par les navigateurs."
  echo "  Once DNS is validated, switch to production :"
  echo "    bash scripts/bootstrap-cert-manager.sh ${ACME_EMAIL}"
else
  echo "  ℹ  Mode PRODUCTION — rate limits Let's Encrypt (5 certs/domaine/7j)."
fi
