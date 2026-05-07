#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# bootstrap-cert-manager.sh — installe cert-manager + ClusterIssuer
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/bootstrap-cert-manager.sh [ACME_EMAIL] [--staging]
#
#   ACME_EMAIL : email pour Let's Encrypt.
#                Priorité : argument > variable d'env > .env
#   --staging  : utiliser letsencrypt-staging (recommandé pour tester)
#
# Idempotent — si cert-manager est déjà installé, saute l'installation.
# Prérequis : kubectl configuré sur le cluster cible.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh introuvable"; exit 1; }
ensure_repo_root

# ── Chargement .env — UNE SEULE FOIS via load_env (FIX B1) ───────────────────
load_env

# ── Versions — overridables depuis .env (FIX B4) ─────────────────────────────
CERTMANAGER_VERSION="${CERTMANAGER_VERSION:-v1.16.2}"
CERTMANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/${CERTMANAGER_VERSION}/cert-manager.yaml"
CERTMANAGER_SHA256="${CERTMANAGER_SHA256:-}"   # FIX B4 : vide par défaut, override via .env

# ── Arguments : priorité arg > .env (FIX B1 — ordre correct) ─────────────────
# load_env a positionné ACME_EMAIL depuis .env si présent.
# L'argument positionnel $1 (si fourni et non --staging) prend priorité.
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

# ACME_EMAIL obligatoire pour Let's Encrypt — optionnel en mode --opensearch-pki seul
if [[ -z "${ACME_EMAIL}" ]]; then
  if ${INSTALL_OPENSEARCH_PKI} && ! ${USE_STAGING}; then
    log_warn "ACME_EMAIL absent — PKI OpenSearch interne uniquement (pas de Let's Encrypt Ingress)."
  else
    log_err "Email ACME requis pour Let's Encrypt."
    log_err "  Usage : bash scripts/bootstrap-cert-manager.sh ops@mycompany.com"
    log_err "  Ou   : make bootstrap-cert-manager ACME_EMAIL=ops@mycompany.com"
    exit 1
  fi
else
  validate_email "${ACME_EMAIL}" || exit 1
fi

# ── ClusterIssuer — génération automatique si absent ─────────────────────────
CLUSTER_ISSUER_FILE="k8s/base/cert-manager/cluster-issuer-configured.yaml"
if [[ ! -f "${CLUSTER_ISSUER_FILE}" ]]; then
  log_info "ClusterIssuer absent — génération automatique avec l'email ${ACME_EMAIL}..."
  bash scripts/configure-domain.sh "${PROVIDER:-gcp}" "${DOMAIN:-example.com}" "${ACME_EMAIL}" || true
fi

log_step "Bootstrap cert-manager ${CERTMANAGER_VERSION}"
log_info "Email ACME : ${ACME_EMAIL}"
if ${USE_STAGING}; then _MODE="STAGING (tests)"; else _MODE="PRODUCTION"; fi
log_info "Mode       : ${_MODE}"

# ── 1. Vérifier si cert-manager est déjà installé ────────────────────────────
if kubectl get namespace cert-manager &>/dev/null && \
   kubectl -n cert-manager get deploy cert-manager &>/dev/null 2>/dev/null; then
  INSTALLED=$(kubectl -n cert-manager get deploy cert-manager \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null \
    | grep -oP 'v[\d.]+' | head -1 || echo "inconnue")
  log_info "cert-manager déjà installé (version détectée : ${INSTALLED})"
  if [[ "${INSTALLED}" == "${CERTMANAGER_VERSION}" ]]; then
    log_ok "Version à jour — installation sautée"
  else
    log_warn "Version ${INSTALLED} ≠ ${CERTMANAGER_VERSION} — mise à jour..."
    kubectl apply -f "${CERTMANAGER_URL}"
  fi
else
  # ── 2. Télécharger + vérifier ─────────────────────────────────────────────
  TMPDIR="$(mktemp -d)"
  # shellcheck disable=SC2064  # intentionnel : expansion immédiate pour capturer TMPDIR
  trap "rm -rf ${TMPDIR}" EXIT

  log_info "Téléchargement cert-manager ${CERTMANAGER_VERSION}..."
  if ! curl -sLf --max-time 60 -o "${TMPDIR}/cert-manager.yaml" "${CERTMANAGER_URL}"; then
    log_err "Impossible de télécharger cert-manager : ${CERTMANAGER_URL}"
    exit 1
  fi

  if [[ -n "${CERTMANAGER_SHA256}" ]]; then
    ACTUAL=$(sha256sum "${TMPDIR}/cert-manager.yaml" | cut -d' ' -f1)
    if [[ "${ACTUAL}" != "${CERTMANAGER_SHA256}" ]]; then
      log_err "SHA256 mismatch cert-manager !"
      log_err "  Attendu : ${CERTMANAGER_SHA256}"
      log_err "  Obtenu  : ${ACTUAL}"
      log_err "  Arrêt — ne pas installer un manifest compromis."
      exit 1
    fi
    log_ok "SHA256 vérifié"
  else
    log_warn "SHA256 non vérifié — override via CERTMANAGER_SHA256 dans .env pour sécuriser"
  fi

  log_info "Installation cert-manager ${CERTMANAGER_VERSION}..."
  kubectl apply -f "${TMPDIR}/cert-manager.yaml"
  log_ok "Manifest appliqué"
fi

# ── 3. Attente démarrage — via wait_rollout de lib/common.sh (FIX B3) ─────────
# cert-manager a son propre namespace donc on surcharge NS localement
NS="cert-manager"
log_step "Attente démarrage cert-manager (peut prendre 2-3 min)..."
wait_rollout deploy/cert-manager          300
wait_rollout deploy/cert-manager-webhook  300
wait_rollout deploy/cert-manager-cainjector 300

# ── 4. Attendre que le webhook accepte les CRDs ───────────────────────────────
log_info "Attente webhook CRD..."
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
    log_ok "Webhook prêt"
    break
  fi
  [[ "${i}" -eq 20 ]] && { log_err "Timeout webhook cert-manager"; exit 1; }
  log_info "Attente webhook (${i}/20)..."
  sleep 5
done

# ── 5. Appliquer le ClusterIssuer ─────────────────────────────────────────────
if [[ -f "${CLUSTER_ISSUER_FILE}" ]]; then
  if ${USE_STAGING}; then
    kubectl delete clusterissuer letsencrypt-staging --ignore-not-found || true
  fi
  kubectl apply -f "${CLUSTER_ISSUER_FILE}"
  log_ok "ClusterIssuers appliqués"
  echo ""
  kubectl get clusterissuer 2>/dev/null || true
else
  log_warn "${CLUSTER_ISSUER_FILE} introuvable — ClusterIssuer non appliqué"
  log_warn "  Générer : make configure-domain PROVIDER=... DOMAIN=... ACME_EMAIL=..."
fi

# ── 6. PKI OpenSearch (optionnel : --opensearch-pki) ──────────────────────────
if ${INSTALL_OPENSEARCH_PKI}; then
  log_step "Déploiement PKI OpenSearch (CA + Issuer + Certificate)..."
  OPENSEARCH_PKI="k8s/base/cert-manager/opensearch-pki.yaml"
  if [[ ! -f "${OPENSEARCH_PKI}" ]]; then
    log_err "${OPENSEARCH_PKI} introuvable"
    log_err "  Ce fichier doit être présent dans le dépôt."
    exit 1
  fi
  # C3 : créer le namespace avant d'appliquer les ressources namespace-scoped
  log_info "Création du namespace data-platform (si absent)..."
  kubectl apply -f k8s/base/namespace/namespace.yaml
  kubectl apply -f "${OPENSEARCH_PKI}"
  log_ok "PKI OpenSearch appliquée"
  log_info "Note : l'Issuer opensearch-ca-issuer peut être NotReady 30-60s le temps"
  log_info "  que cert-manager émette le Secret opensearch-ca-secret. C'est normal."

  # Attendre que le Secret opensearch-tls-certs soit créé par cert-manager
  log_info "Attente création du Secret opensearch-tls-certs..."
  NS="data-platform"
  for i in $(seq 1 30); do
    if kubectl -n "${NS}" get secret opensearch-tls-certs &>/dev/null; then
      log_ok "Secret opensearch-tls-certs créé par cert-manager"
      break
    fi
    [[ "${i}" -eq 30 ]] && { log_err "Timeout : opensearch-tls-certs non créé"; exit 1; }
    log_info "Attente cert-manager (${i}/30)..."
    sleep 10
  done

  echo ""
  log_info "Certificat TLS OpenSearch :"
  kubectl -n "${NS}" get certificate opensearch-tls 2>/dev/null || true
  echo ""
  log_info "Renouvellement automatique : cert-manager renouvelle 30 jours avant expiry."
  log_info "Pour vérifier : kubectl -n ${NS} get certificate,certificaterequest"
fi

log_done "Bootstrap cert-manager terminé"
echo ""
echo "  État cert-manager :"
kubectl -n cert-manager get pods 2>/dev/null | head -6 || true
echo ""
if ${USE_STAGING}; then
  echo "  ⚠  Mode STAGING — certificats non reconnus par les navigateurs."
  echo "  Quand le DNS est validé, basculer en prod :"
  echo "    bash scripts/bootstrap-cert-manager.sh ${ACME_EMAIL}"
else
  echo "  ℹ  Mode PRODUCTION — rate limits Let's Encrypt (5 certs/domaine/7j)."
fi
