from diagnostik_common.config import RuntimeMode
from diagnostik_common.search import InMemorySearchBackend, OpenSearchSearchBackend, create_search_backend
from diagnostik_common.storage import InMemoryStore, create_metadata_store


def test_runtime_memory_uses_in_memory_store() -> None:
    store = create_metadata_store(RuntimeMode.memory)

    assert isinstance(store, InMemoryStore)


def test_opensearch_runtime_exposes_search_backend_contract() -> None:
    backend = create_search_backend(RuntimeMode.opensearch, "http://localhost:9200", "diagnostik-documents-write")

    assert isinstance(backend, OpenSearchSearchBackend)


def test_postgres_runtime_keeps_poc_metadata_in_memory_until_mvp() -> None:
    store = create_metadata_store(RuntimeMode.postgres)
    backend = create_search_backend(RuntimeMode.postgres, "http://localhost:9200", "diagnostik-documents-write")

    assert isinstance(store, InMemoryStore)
    assert isinstance(backend, InMemorySearchBackend)
