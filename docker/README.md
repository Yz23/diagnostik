# DIAGNOSTIK — Local Dev Stack

Runs the full stack (OpenSearch, Logstash, Kafka, Spark, HDFS, YARN) in single-node mode,
without Kubernetes. Ideal for development and quick testing.

## Quick start

```bash
# From the project root
cp .env.example .env
# Set OPENSEARCH_INITIAL_ADMIN_PASSWORD in .env

make dev          # start the stack
make dev-logs     # follow logs
make dev-down     # stop and remove volumes
```

## Exposed ports (localhost only)

| Service                | Port  |
|------------------------|-------|
| OpenSearch API         | 9200  |
| OpenSearch Dashboards  | 5601  |
| Logstash Beats input   | 5044  |
| Logstash TCP/UDP input | 5000  |
| Logstash HTTP input    | 8080  |
| Kafka internal listener | 9092  |
| Spark master           | 7077  |
| Spark Master UI        | 18081 |
| Spark Worker UI        | 18082 |
| HDFS NameNode UI       | 9870  |
| HDFS RPC               | 8020  |
| YARN ResourceManager   | 8088  |

## Differences vs production Kubernetes

| | Docker (dev) | Kubernetes (prod) |
|---|---|---|
| OpenSearch | 1 node, single-node discovery | 3 master + 3 data + 2 coordinator |
| Kafka | 1 KRaft broker, localhost-only listener | 3 KRaft brokers, internal-only service |
| Spark | 1 master + 1 worker standalone | K8s drivers/executors + HistoryServer |
| HDFS | 1 NameNode, replication=1 | 2 NameNodes HA + 3 JournalNodes |
| YARN | 1 ResourceManager | 2 ResourceManagers HA |
| JVM heap | 512MB per service | 1–4GB per role |
| TLS | disabled | cert-manager PKI (tls.crt/tls.key/ca.crt) |

## Configuration

Edit `.env` before starting. The same file is used by Docker Compose and
the Kubernetes deployment scripts — single source of truth.

Key variables:

| Variable | Description |
|---|---|
| `OPENSEARCH_INITIAL_ADMIN_PASSWORD` | OpenSearch admin secret, set locally in `.env` |
| `KAFKA_ADMIN_PASSWORD` | Kafka admin secret, set locally in `.env` |
| `KAFKA_CLIENT_PASSWORD` | Kafka client secret, set locally in `.env` |
| `OS_MASTER_HEAP` | OpenSearch JVM heap (default: 1g) |
| `LS_HEAP_SIZE` | Logstash JVM heap (default: 1g) |
| `HDFS_NAMENODE_HEAP` | HDFS NameNode JVM heap (default: 1g) |

## Sync configs to k8s/base/

The Logstash, Kafka, Spark configs and fence script are shared between Docker Compose and Kubernetes.
After editing `config/logstash/`, `config/kafka/`, `config/spark/` or `scripts/fence-namenode.sh`, sync to `k8s/base/`:

```bash
make sync-configs
```
