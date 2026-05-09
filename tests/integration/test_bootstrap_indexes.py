from config.opensearch.index_templates import documents_v1  # type: ignore


def test_placeholder_import_path() -> None:
    # Keeps the integration test directory active; real OpenSearch tests run with the local stack.
    assert documents_v1 is not None
