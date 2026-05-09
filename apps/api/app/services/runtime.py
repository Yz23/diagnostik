from __future__ import annotations

from pathlib import Path

from connectors.mock import MockConnector
from diagnostik_common.connectors import ConnectorRegistry
from diagnostik_common.embedding import MockEmbeddingProvider
from diagnostik_common.pipelines import PipelineEngine
from diagnostik_common.search import SearchService
from diagnostik_common.storage import store


registry = ConnectorRegistry()
registry.register(MockConnector())

embedding_provider = MockEmbeddingProvider()
pipeline_engine = PipelineEngine(store=store, embedding_provider=embedding_provider)
search_service = SearchService(store=store, embedding_provider=embedding_provider)


def default_pipeline_path() -> Path:
    return Path(__file__).resolve().parents[4] / "pipelines" / "templates" / "default_text_indexing.yml"
