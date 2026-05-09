import os
from functools import lru_cache
from pydantic import BaseModel


class Settings(BaseModel):
    environment: str = "local"
    service_name: str = "diagnostik"
    version: str = "0.1.0"
    auth_mode: str = "none"
    api_key: str | None = None
    plugin_path: str | None = None
    opensearch_url: str = "http://localhost:9200"
    documents_index: str = "diagnostik-documents-write"
    max_payload_bytes: int = 2_000_000
    cors_origins: str = "http://localhost:8501,http://localhost:3000"


@lru_cache
def get_settings() -> Settings:
    return Settings(
        environment=os.getenv("DIAGNOSTIK_ENVIRONMENT", "local"),
        service_name=os.getenv("DIAGNOSTIK_SERVICE_NAME", "diagnostik"),
        version=os.getenv("DIAGNOSTIK_VERSION", "0.1.0"),
        auth_mode=os.getenv("DIAGNOSTIK_AUTH_MODE", "none"),
        api_key=os.getenv("DIAGNOSTIK_API_KEY") or None,
        plugin_path=os.getenv("DIAGNOSTIK_PLUGIN_PATH") or None,
        opensearch_url=os.getenv("DIAGNOSTIK_OPENSEARCH_URL", "http://localhost:9200"),
        documents_index=os.getenv("DIAGNOSTIK_DOCUMENTS_INDEX", "diagnostik-documents-write"),
        max_payload_bytes=int(os.getenv("DIAGNOSTIK_MAX_PAYLOAD_BYTES", "2000000")),
        cors_origins=os.getenv("DIAGNOSTIK_CORS_ORIGINS", "http://localhost:8501,http://localhost:3000"),
    )
