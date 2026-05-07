#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# configure-domain.sh — génère les patches kustomize Ingress + ClusterIssuer
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/configure-domain.sh <PROVIDER> <DOMAIN> [EMAIL]
#   PROVIDER : gcp | aws | azure
#   DOMAIN   : mycompany.com
#   EMAIL    : ops@mycompany.com  (défaut: admin@DOMAIN)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh introuvable"; exit 1; }
ensure_repo_root
load_env

PROVIDER="${1:-${PROVIDER:-}}"
DOMAIN="${2:-${DOMAIN:-}}"
EMAIL="${3:-${ACME_EMAIL:-admin@${DOMAIN:-}}}"

usage() {
  echo "Usage: bash scripts/configure-domain.sh <PROVIDER> <DOMAIN> [EMAIL]"
  echo "  bash scripts/configure-domain.sh gcp mycompany.com ops@mycompany.com"
  echo "  Variables .env acceptées : PROVIDER, DOMAIN, ACME_EMAIL"
  exit 1
}

# ── Validation des inputs (SOLID-S) ──────────────────────────────────────────
[ -z "${PROVIDER}" ] && { log_err "PROVIDER requis"; usage; }
[ -z "${DOMAIN}"   ] && { log_err "DOMAIN requis";   usage; }

# Cas spécial : provider local n'a pas d'Ingress externe
if ! provider_has_dns_ingress "${PROVIDER}"; then
  echo "INFO : provider '${PROVIDER}' — kubectl port-forward utilisé, pas d'Ingress DNS."
  exit 0
fi

validate_provider "${PROVIDER}" || exit 1
validate_domain   "${DOMAIN}"   || exit 1

# Email : dériver de DOMAIN si absent, puis valider
EMAIL="${EMAIL:-admin@${DOMAIN}}"
validate_email "${EMAIL}" || exit 1

OVERLAY_DIR="k8s/overlays/${PROVIDER}"
PATCH_FILE="${OVERLAY_DIR}/patches/ingress-domain.yaml"
CERTMGR_FILE="k8s/base/cert-manager/cluster-issuer-configured.yaml"

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  log_err "Overlay introuvable : ${OVERLAY_DIR}"
  exit 1
fi

log_step "Configuration domaine Ingress : ${PROVIDER} → ${DOMAIN}"

# ── 1. Patch Ingress kustomize ────────────────────────────────────────────────
cat > "${PATCH_FILE}" << EOF
# Généré par scripts/configure-domain.sh — NE PAS COMMITER
# Domaine : ${DOMAIN} | Généré : $(date -u +"%Y-%m-%dT%H:%M:%SZ")

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opensearch-dashboards-ingress
  namespace: data-platform
spec:
  tls:
    - hosts:
        - dashboards.${DOMAIN}
      secretName: dashboards-tls-cert
  rules:
    - host: dashboards.${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: opensearch-dashboards, port: { number: 5601 } }
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yarn-ui-ingress
  namespace: data-platform
spec:
  tls:
    - hosts:
        - yarn.${DOMAIN}
      secretName: yarn-tls-cert
  rules:
    - host: yarn.${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: yarn-resourcemanager, port: { number: 8088 } }
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hdfs-ui-ingress
  namespace: data-platform
spec:
  tls:
    - hosts:
        - hdfs.${DOMAIN}
      secretName: hdfs-tls-cert
  rules:
    - host: hdfs.${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: hdfs-namenode, port: { number: 9870 } }
EOF
log_ok "Patch Ingress généré : ${PATCH_FILE}"

# ── 2. ClusterIssuer cert-manager ─────────────────────────────────────────────
cat > "${CERTMGR_FILE}" << EOF
# Généré par scripts/configure-domain.sh — NE PAS COMMITER
# Email : ${EMAIL} | Généré : $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Appliquer après bootstrap-cert-manager.sh :
#   kubectl apply -f ${CERTMGR_FILE}

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
log_ok "ClusterIssuer configuré : ${CERTMGR_FILE}"

# ── 3. Persister dans .env ─────────────────────────────────────────────────────
if [[ -f ".env" ]]; then
  { grep -v "^DOMAIN=\|^ACME_EMAIL=" .env; \
    echo "DOMAIN=${DOMAIN}"; echo "ACME_EMAIL=${EMAIL}"; } > /tmp/.env.new && mv /tmp/.env.new .env
  log_ok "DOMAIN + ACME_EMAIL mis à jour dans .env"
fi

log_done "Domaine configuré : ${DOMAIN}"
echo ""
echo "  Enregistrements DNS à créer (A records → IP externe du LoadBalancer) :"
echo "    dashboards.${DOMAIN}"
echo "    yarn.${DOMAIN}"
echo "    hdfs.${DOMAIN}"
echo ""
echo "  Étapes suivantes :"
echo "    1. make bootstrap-cert-manager ACME_EMAIL=${EMAIL} ARGS=--staging"
echo "    2. kubectl apply -f ${CERTMGR_FILE}"
echo "    3. PROVIDER=${PROVIDER} make deploy"
