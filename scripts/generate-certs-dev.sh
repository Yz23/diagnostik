#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# generate-certs-dev.sh — certificats auto-signés pour OpenSearch (dev K8s)
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/generate-certs-dev.sh  (ou : make secret-tls)
#
# Génère une CA auto-signée + certificat TLS pour OpenSearch (transport + HTTP).
# Crée le Secret opensearch-tls-certs avec les noms standard cert-manager :
#   tls.crt — certificat
#   tls.key — clé privée
#   ca.crt  — CA certificate
#
# En PRODUCTION, utiliser cert-manager (auto-renouvellement) :
#   make bootstrap-cert-manager
#   kubectl apply -f k8s/base/cert-manager/opensearch-pki.yaml
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NS="data-platform"
OUT="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf ${OUT}" EXIT

echo "==> Génération des certificats OpenSearch (dev)..."

# ── CA Root (4096 bits — longue durée) ────────────────────────────────────────
openssl genrsa -out "${OUT}/ca.key" 4096 2>/dev/null
openssl req -new -x509 -sha256 \
  -key "${OUT}/ca.key" \
  -out "${OUT}/ca.crt" \
  -days 730 \
  -subj "/C=FR/O=data-platform-dev/CN=opensearch-root-ca" 2>/dev/null

# ── Certificat OpenSearch (3072 bits — transport + HTTP) ──────────────────────
# Un seul certificat couvre transport inter-nœuds ET API HTTP.
# Les SANs couvrent tous les noms DNS internes OpenSearch.
openssl genrsa -out "${OUT}/tls.key" 3072 2>/dev/null
openssl req -new \
  -key "${OUT}/tls.key" \
  -out "${OUT}/tls.csr" \
  -subj "/C=FR/O=data-platform-dev/CN=opensearch.data-platform" 2>/dev/null
openssl x509 -req -sha256 \
  -in "${OUT}/tls.csr" \
  -CA "${OUT}/ca.crt" -CAkey "${OUT}/ca.key" -CAcreateserial \
  -out "${OUT}/tls.crt" -days 365 \
  -extfile <(printf \
    "subjectAltName=DNS:opensearch,DNS:opensearch-master-headless,DNS:opensearch-data-headless,DNS:opensearch-coordinator,DNS:opensearch.data-platform.svc,DNS:opensearch.data-platform.svc.cluster.local,DNS:localhost" \
  ) 2>/dev/null

# ── Secret Kubernetes ─────────────────────────────────────────────────────────
# Noms de clés : tls.crt / tls.key / ca.crt (standard cert-manager)
# Compatible avec la configuration opensearch.yml et cert-manager Certificate CRD.
kubectl apply -f k8s/base/namespace/namespace.yaml
kubectl -n "${NS}" create secret generic opensearch-tls-certs \
  --from-file=tls.crt="${OUT}/tls.crt" \
  --from-file=tls.key="${OUT}/tls.key" \
  --from-file=ca.crt="${OUT}/ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret 'opensearch-tls-certs' créé dans le namespace ${NS}"
echo ""
echo "  Clés : tls.crt, tls.key, ca.crt"
echo "  Montées dans les pods OpenSearch sous /usr/share/opensearch/config/certs/"
echo ""
echo "  ⚠  Certificats auto-signés — DÉVELOPPEMENT UNIQUEMENT (365 jours)"
echo "  En production : kubectl apply -f k8s/base/cert-manager/opensearch-pki.yaml"
