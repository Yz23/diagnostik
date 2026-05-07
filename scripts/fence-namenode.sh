#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# fence-namenode.sh — Fencing K8s-natif pour HDFS NameNode HA
# ══════════════════════════════════════════════════════════════════════════════
#
# Appelé par ZKFC lors d'un failover automatique OU d'un failover manuel :
#   hdfs haadmin -failover nn0 nn1
#
# HDFS passe l'adresse du nœud à fencer comme arguments :
#   fence-namenode.sh <hostname-ou-ip> <port>
#   Exemple : fence-namenode.sh hdfs-namenode-0.hdfs-namenode-headless.data-platform.svc.cluster.local 8020
#
# Ce script :
#   1. Extrait l'ordinal du pod depuis le DNS du StatefulSet
#   2. Force-delete le pod via l'API Kubernetes (depuis l'intérieur du cluster)
#   3. Sort avec le code de sortie approprié (0 = succès, 1 = échec)
#
# Prérequis :
#   • ServiceAccount hdfs-namenode avec permission pods/delete sur le namespace
#   • Token SA monté (automountServiceAccountToken: true sur le SA hdfs-namenode)
#   • Ce script monté dans le pod depuis le ConfigMap hdfs-fence-script
#
# IMPORTANT : le fencing est une dernière ligne de défense. ZKFC via ZooKeeper
# est le mécanisme principal. Ce script protège contre le scénario "GC pause +
# récupération tardive" où le NN actif reprend son activité après qu'un autre
# NN a pris le leadership.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

TARGET_HOST="${1:-}"
TARGET_PORT="${2:-}"

if [ -z "$TARGET_HOST" ]; then
  echo "FENCING ERROR: No target host provided" >&2
  exit 1
fi

# ── Extraire l'ordinal du pod depuis le hostname DNS du StatefulSet ──────────
# Format attendu : hdfs-namenode-<ORDINAL>.hdfs-namenode-headless[.namespace.svc.cluster.local][:port]
ORDINAL=$(echo "$TARGET_HOST" | grep -oP '(?<=hdfs-namenode-)\d+' | head -1 || true)

if [ -z "$ORDINAL" ]; then
  echo "FENCING ERROR: Cannot extract NameNode ordinal from target: $TARGET_HOST" >&2
  echo "  Expected format: hdfs-namenode-<N>.hdfs-namenode-headless..." >&2
  exit 1
fi

POD_NAME="hdfs-namenode-${ORDINAL}"
NAMESPACE="${POD_NAMESPACE:-data-platform}"
APISERVER="https://kubernetes.default.svc"

# ── Token ServiceAccount monté par Kubernetes ─────────────────────────────────
TOKEN_FILE="/var/run/secrets/kubernetes.io/serviceaccount/token"
CACERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "FENCING ERROR: ServiceAccount token not found at $TOKEN_FILE" >&2
  echo "  Verify automountServiceAccountToken=true on ServiceAccount hdfs-namenode" >&2
  exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "FENCING: Force-deleting pod $POD_NAME in namespace $NAMESPACE..."

# ── Appel API K8s : DELETE pod avec gracePeriodSeconds=0 ─────────────────────
HTTP_CODE=$(curl \
  --silent \
  --output /tmp/fence-response.json \
  --write-out "%{http_code}" \
  --request DELETE \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" \
  --cacert "$CACERT" \
  --max-time 30 \
  "${APISERVER}/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}?gracePeriodSeconds=0")

case "$HTTP_CODE" in
  200|202)
    echo "FENCING SUCCESS: Pod $POD_NAME deleted (HTTP $HTTP_CODE)"
    exit 0
    ;;
  404)
    # Pod introuvable = déjà arrêté = fencing réussi par définition
    echo "FENCING SUCCESS: Pod $POD_NAME already gone (HTTP 404)"
    exit 0
    ;;
  403)
    echo "FENCING ERROR: Permission denied (HTTP 403)" >&2
    echo "  Verify RBAC: ServiceAccount hdfs-namenode needs pods/delete permission" >&2
    cat /tmp/fence-response.json >&2
    exit 1
    ;;
  *)
    echo "FENCING ERROR: Unexpected HTTP $HTTP_CODE" >&2
    cat /tmp/fence-response.json >&2
    exit 1
    ;;
esac
