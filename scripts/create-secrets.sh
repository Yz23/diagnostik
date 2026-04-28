#!/usr/bin/env bash
set -euo pipefail
NS="data-platform"
if [[ -z "${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}" ]]; then
  echo "ERROR: OPENSEARCH_INITIAL_ADMIN_PASSWORD is not set."
  echo "  export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'"
  exit 1
fi
kubectl apply -f k8s/base/namespace/namespace.yaml
kubectl -n "$NS" create secret generic opensearch-credentials \
  --from-literal=OPENSEARCH_INITIAL_ADMIN_PASSWORD="${OPENSEARCH_INITIAL_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Secret created."
