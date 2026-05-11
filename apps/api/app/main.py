from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.observability.middleware import RequestIdMiddleware
from app.routers import connectors, datasets, health, pipelines, search, workspaces
from diagnostik_common.config import get_settings
from diagnostik_common.logging import configure_logging


settings = get_settings()
configure_logging(service="diagnostik-api", environment=settings.environment)

app = FastAPI(
    title="Diagnostik Community Platform API",
    version=settings.version,
    description="Open-source Data & AI platform for ingestion, enrichment, indexing and exploration.",
)

app.add_middleware(RequestIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(workspaces.router)
app.include_router(datasets.router)
app.include_router(connectors.router)
app.include_router(pipelines.router)
app.include_router(search.router)
