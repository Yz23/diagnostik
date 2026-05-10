# Roadmap

## POC

- Product-oriented public community platform positioning.
- FastAPI POC with health, connector, dataset, pipeline, and search endpoints.
- Mock connector demo end-to-end.
- Pipeline YAML engine with mock embeddings.
- `DIAGNOSTIK_RUNTIME=memory` as the supported POC runtime.
- API key enforcement on write and admin endpoints when `DIAGNOSTIK_AUTH_MODE=api_key`.
- OpenSearch templates for documents, embeddings, and audit events.
- Streamlit UI POC.
- App CI with ruff, mypy, pytest, pip-audit, and bandit.
- Private plugin loading through `DIAGNOSTIK_PLUGIN_PATH`.

## MVP

- Persistent workspace and metadata store with PostgreSQL.
- API key hardening plus JWT/OIDC integration.
- OpenSearch search backend implementation behind the `DIAGNOSTIK_RUNTIME=opensearch` contract.
- Kafka-backed workers for asynchronous connector and pipeline execution.
- File, API, RSS, database, and compliant public web data source adapters.
- Durable OpenSearch indexing and reindex workflows.
- Monitoring dashboards and metrics export.
- Versioned plugin SDK and contributor workflow.

## Production

- Kubernetes-ready API, worker, and UI deployments with HA.
- OIDC, RBAC, External Secrets, and tenant isolation.
- Backup and restore for metadata, object storage, and indexes.
- Full observability: metrics, logs, traces, audit retention.
- Supply-chain security gates and release provenance.
- Community connector and pipeline marketplace.

## Private Use Cases

- Private repository, private plugins, private connectors, private datasets, private indexes, specialized models, private dashboards.
