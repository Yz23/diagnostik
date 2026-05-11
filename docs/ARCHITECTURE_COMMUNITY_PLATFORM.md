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

The first POC uses in-memory metadata and mock embeddings. Production-ready implementations can swap storage, queue, embedding, and indexing providers behind the shared interfaces.
