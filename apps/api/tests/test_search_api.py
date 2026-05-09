from fastapi.testclient import TestClient

from app.main import app
from diagnostik_common.storage import store


def test_mock_ingest_pipeline_and_search() -> None:
    store.reset()
    client = TestClient(app)

    ingest = client.post("/connectors/mock/runs", json={"workspace_id": "default", "dataset_id": "demo", "count": 3})
    assert ingest.status_code == 200
    assert ingest.json()["records_written"] == 3

    pipeline = client.post("/pipelines/default_text_indexing/runs", json={"dataset_id": "demo"})
    assert pipeline.status_code == 200
    assert pipeline.json()["status"] == "succeeded"

    search = client.post(
        "/search/text",
        json={"workspace_id": "default", "dataset_ids": ["demo"], "query": "cybersecurity", "limit": 5},
    )
    assert search.status_code == 200
    assert len(search.json()) >= 1
