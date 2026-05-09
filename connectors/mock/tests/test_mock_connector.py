from connectors.mock import MockConnector


def test_mock_connector_fetches_documents() -> None:
    connector = MockConnector()
    result = connector.dry_run({"count": 2})
    records = list(connector.fetch({"dataset_id": "demo", "count": 2, "domain": "finance"}))
    document = connector.normalize(records[0])

    assert result.ok is True
    assert len(records) == 2
    assert document.dataset_id == "demo"
    assert document.text
