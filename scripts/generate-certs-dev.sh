#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# generate-certs-dev.sh — self-signed certificates for OpenSearch (dev K8s)
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/generate-certs-dev.sh  (ou : make secret-tls)
#
# Generates a self-signed CA + TLS certificate for OpenSearch (transport + HTTP).
# Creates the opensearch-tls-certs Secret with standard cert-manager key names :
#   tls.crt — certificat
#   tls.key — private key
#   ca.crt  — CA certificate
#
# In PRODUCTION, use cert-manager (auto-renewal) :
#   make bootstrap-cert-manager
#   kubectl apply -f k8s/base/cert-manager/opensearch-pki.yaml
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NS="data-platform"
OUT="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf ${OUT}" EXIT

echo "==> Generating OpenSearch certificates (dev)..."

# ── Root CA (4096 bits — long duration) ────────────────────────────────────────
openssl genrsa -out "${OUT}/ca.key" 4096 2>/dev/null
openssl req -new -x509 -sha256 \
  -key "${OUT}/ca.key" \
  -out "${OUT}/ca.crt" \
  -days 730 \
  -subj "/C=FR/O=data-platform-dev/CN=opensearch-root-ca" 2>/dev/null

# ── OpenSearch Certificate (3072 bits — transport + HTTP) ──────────────────────
# A single certificate covers both inter-node transport AND HTTP API.
# SANs cover all internal OpenSearch DNS names.
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

# ── Kubernetes Secret ─────────────────────────────────────────────────────────
# Key names: tls.crt / tls.key / ca.crt (cert-manager standard)
# Compatible with opensearch.yml configuration and cert-manager Certificate CRD.
kubectl apply -f k8s/base/namespace/namespace.yaml
kubectl -n "${NS}" create secret generic opensearch-tls-certs \
  --from-file=tls.crt="${OUT}/tls.crt" \
  --from-file=tls.key="${OUT}/tls.key" \
  --from-file=ca.crt="${OUT}/ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret 'opensearch-tls-certs' created dans le namespace ${NS}"
echo ""
echo "  Keys: tls.crt, tls.key, ca.crt"
echo "  Mounted in OpenSearch pods at /usr/share/opensearch/config/certs/"
echo ""
echo "  ⚠  Self-signed certificates — DEVELOPMENT ONLY (365 days)"
echo "  In production : kubectl apply -f k8s/base/cert-manager/opensearch-pki.yaml"
