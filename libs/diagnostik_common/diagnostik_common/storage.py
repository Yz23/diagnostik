from __future__ import annotations

from typing import Protocol

from diagnostik_common.config import RuntimeMode, get_settings
from diagnostik_common.schemas import Dataset, Document, EmbeddingRecord, Pipeline, PipelineRun, Workspace


class MetadataStore(Protocol):
    workspaces: dict[str, Workspace]
    datasets: dict[str, Dataset]
    documents: dict[str, Document]
    embeddings: dict[str, EmbeddingRecord]
    pipelines: dict[str, Pipeline]
    pipeline_runs: dict[str, PipelineRun]

    def reset(self) -> None: ...


class DurableMetadataStore(Protocol):
    """Contract for a future PostgreSQL-backed metadata repository."""

    def connect(self) -> None: ...

    def close(self) -> None: ...


class InMemoryStore:
    def __init__(self) -> None:
        self.workspaces: dict[str, Workspace] = {}
        self.datasets: dict[str, Dataset] = {}
        self.documents: dict[str, Document] = {}
        self.embeddings: dict[str, EmbeddingRecord] = {}
        self.pipelines: dict[str, Pipeline] = {}
        self.pipeline_runs: dict[str, PipelineRun] = {}

    def reset(self) -> None:
        self.workspaces.clear()
        self.datasets.clear()
        self.documents.clear()
        self.embeddings.clear()
        self.pipelines.clear()
        self.pipeline_runs.clear()


class PostgresMetadataStore:
    """PostgreSQL metadata interface placeholder for the MVP runtime."""

    def __init__(self, dsn: str) -> None:
        self.dsn = dsn

    def connect(self) -> None:
        raise NotImplementedError("PostgreSQL metadata is planned for MVP; use DIAGNOSTIK_RUNTIME=memory for the POC.")

    def close(self) -> None:
        raise NotImplementedError("PostgreSQL metadata is planned for MVP; use DIAGNOSTIK_RUNTIME=memory for the POC.")


def create_metadata_store(runtime: RuntimeMode) -> MetadataStore:
    # The public POC keeps metadata in memory. Durable stores plug into this factory in the MVP.
    if runtime in {RuntimeMode.memory, RuntimeMode.opensearch, RuntimeMode.postgres}:
        return InMemoryStore()
    return InMemoryStore()


store = create_metadata_store(get_settings().runtime)
