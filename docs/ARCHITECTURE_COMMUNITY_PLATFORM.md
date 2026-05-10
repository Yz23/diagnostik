# Community Platform Architecture

Logical flow:

```text
User / Community UI / API
  -> Workspace Manager
  -> Connector Registry
  -> Ingestion Engine
  -> Kafka / Queue
  -> Pipeline Engine
  -> Storage Layer
  -> AI Enrichment
  -> Embedding Engine
  -> OpenSearch / Vector Search
  -> Search API
  -> Exploration UI
```

The first POC uses `DIAGNOSTIK_RUNTIME=memory`, in-memory metadata, and mock embeddings. MVP backends can plug into the same contracts with `DIAGNOSTIK_RUNTIME=opensearch` for search and `DIAGNOSTIK_RUNTIME=postgres` for durable metadata.
