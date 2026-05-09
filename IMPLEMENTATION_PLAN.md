# Diagnostik Community Platform Implementation Plan

## Product Direction

Diagnostik becomes an open-source community Data & AI platform for on-demand ingestion, enrichment, indexing, semantic search, and AI-powered exploration.

The public core is intentionally generic. Private use cases, proprietary connectors, private datasets, and domain-specific strategies must live outside this repository and be loaded as plugins.

## Iteration 1 Scope

- Create the app structure: `apps/api`, `apps/worker`, `apps/ui`.
- Create shared contracts in `libs/diagnostik_common`.
- Add public-safe connector architecture and a working mock connector.
- Add pipeline YAML templates and a small pipeline engine.
- Add OpenSearch index templates for documents, embeddings, and audit events.
- Add FastAPI endpoints for health, version, connectors, datasets, pipelines, documents, and search.
- Add Streamlit UI scaffold.
- Add unit tests for schemas, connectors, pipeline engine, API health, and search.
- Add Make targets for app install, dev, tests, bootstrap, mock ingestion, pipeline run, and search demo.

## Design Principles

- Secure by design: no committed secrets, API key mode prepared, private plugin path isolated.
- SOLID: connector, embedding, search, and pipeline responsibilities are separated.
- Atomic: public core changes are isolated from infrastructure and private use cases.
- DRY: shared models and runtime contracts live in `diagnostik_common`.
- Community-first: public connectors are generic and safe.

## Not In Scope

- No private-domain-specific connector in the public repository.
- No private dataset.
- No proprietary pipeline.
- No external AI provider enabled by default.
- No dependency on a hosted AI vendor.

## Next Iterations

- PostgreSQL metadata persistence.
- Kafka-backed async worker execution.
- OpenSearch live indexing client.
- File/API/RSS/database connector implementations.
- OIDC/JWT auth.
- Kubernetes manifests for API, worker, UI, PostgreSQL, and MinIO.
- Community plugin discovery and versioning.
