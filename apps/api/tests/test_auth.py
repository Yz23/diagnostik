from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.main import app
from diagnostik_common.config import get_settings
from diagnostik_common.storage import store


@pytest.fixture(autouse=True)
def clear_settings_cache() -> Iterator[None]:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_write_endpoint_requires_api_key_when_enabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DIAGNOSTIK_AUTH_MODE", "api_key")
    monkeypatch.setenv("DIAGNOSTIK_API_KEY", "test-key")
    get_settings.cache_clear()
    store.reset()
    client = TestClient(app)

    payload = {"workspace_id": "default", "dataset_id": "demo", "count": 1}
    rejected = client.post("/connectors/mock/runs", json=payload)
    accepted = client.post("/connectors/mock/runs", json=payload, headers={"X-API-Key": "test-key"})

    assert rejected.status_code == 401
    assert accepted.status_code == 200


def test_admin_endpoint_requires_configured_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DIAGNOSTIK_AUTH_MODE", "api_key")
    monkeypatch.delenv("DIAGNOSTIK_API_KEY", raising=False)
    get_settings.cache_clear()
    client = TestClient(app)

    response = client.get("/admin/stats", headers={"X-API-Key": "anything"})

    assert response.status_code == 503
