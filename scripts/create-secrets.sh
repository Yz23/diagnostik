#!/usr/bin/env bash
set -euo pipefail
NS="data-platform"
if [[ -z "${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}" ]]; then
  echo "ERROR: OPENSEARCH_INITIAL_ADMIN_PASSWORD is not set."
  echo "  export OPENSEARCH_INITIAL_ADMIN_PASSWORD='YourStr0ng!Pass1'"
  exit 1
fi
if [[ -z "${KAFKA_ADMIN_PASSWORD:-}" || -z "${KAFKA_CLIENT_PASSWORD:-}" ]]; then
  echo "ERROR: KAFKA_ADMIN_PASSWORD and KAFKA_CLIENT_PASSWORD must be set."
  echo "  export KAFKA_ADMIN_PASSWORD='YourStr0ng!KafkaAdmin1'"
  echo "  export KAFKA_CLIENT_PASSWORD='YourStr0ng!KafkaClient1'"
  exit 1
fi
kubectl apply -f k8s/base/namespace/namespace.yaml
kubectl -n "$NS" create secret generic opensearch-credentials \
  --from-literal=OPENSEARCH_INITIAL_ADMIN_PASSWORD="${OPENSEARCH_INITIAL_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create secret generic kafka-credentials \
  --from-literal=KAFKA_ADMIN_PASSWORD="${KAFKA_ADMIN_PASSWORD}" \
  --from-literal=KAFKA_CLIENT_PASSWORD="${KAFKA_CLIENT_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Secrets created in namespace $NS"
