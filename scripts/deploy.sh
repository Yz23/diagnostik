#!/usr/bin/env bash
set -euo pipefail
PROVIDER="${1:-gcp}"
NS="data-platform"

if ! kubectl -n "$NS" get secret opensearch-credentials &>/dev/null; then
  echo "ERROR: Secret opensearch-credentials not found."
  echo "  Run: bash scripts/create-secrets.sh"
  exit 1
fi

echo "==> Namespace..."
kubectl apply -f k8s/base/namespace/namespace.yaml

echo "==> ZooKeeper..."
kubectl apply -f k8s/base/hdfs/services.yaml
kubectl apply -f k8s/base/hdfs/statefulset-zookeeper.yaml
kubectl -n "$NS" rollout status statefulset/zookeeper --timeout=180s

echo "==> HDFS JournalNodes..."
kubectl apply -f k8s/base/hdfs/statefulset-journalnode.yaml
kubectl -n "$NS" rollout status statefulset/hdfs-journalnode --timeout=180s

echo "==> HDFS NameNodes..."
kubectl apply -f k8s/base/hdfs/configmap.yaml
kubectl apply -f k8s/base/hdfs/statefulset-namenode.yaml
kubectl -n "$NS" rollout status statefulset/hdfs-namenode --timeout=300s

echo "==> HDFS DataNodes..."
kubectl apply -f k8s/base/hdfs/statefulset-datanode.yaml

echo "==> YARN..."
kubectl apply -f k8s/base/yarn/services.yaml
kubectl apply -f k8s/base/yarn/statefulset-resourcemanager.yaml
kubectl -n "$NS" rollout status statefulset/yarn-resourcemanager --timeout=180s
kubectl apply -f k8s/base/yarn/daemonset-nodemanager.yaml
kubectl apply -f k8s/base/yarn/deployment-historyserver.yaml

echo "==> OpenSearch + Dashboards + Logstash..."
kubectl kustomize k8s/overlays/"$PROVIDER" | kubectl apply -f -

echo ""
echo "Done. Check status:"
echo "  kubectl -n $NS get pods -o wide"
