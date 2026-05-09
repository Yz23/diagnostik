from __future__ import annotations

from pathlib import Path

from connectors.mock import MockConnector
from diagnostik_common.config import get_settings
from diagnostik_common.connectors import ConnectorRegistry, load_connector_plugins
from diagnostik_common.embedding import MockEmbeddingProvider
from diagnostik_common.pipelines import PipelineEngine
from diagnostik_common.search import SearchService
from diagnostik_common.storage import store


registry = ConnectorRegistry()
registry.register(MockConnector())
_settings = get_settings()
_repo_root = Path(__file__).resolve().parents[4]
_plugin_paths = [_repo_root / "plugins" / "examples"]
if _settings.plugin_path:
    _plugin_paths.append(Path(_settings.plugin_path))
loaded_plugins = load_connector_plugins(registry, _plugin_paths)

embedding_provider = MockEmbeddingProvider()
pipeline_engine = PipelineEngine(store=store, embedding_provider=embedding_provider)
search_service = SearchService(store=store, embedding_provider=embedding_provider)


def default_pipeline_path() -> Path:
    return Path(__file__).resolve().parents[4] / "pipelines" / "templates" / "default_text_indexing.yml"
