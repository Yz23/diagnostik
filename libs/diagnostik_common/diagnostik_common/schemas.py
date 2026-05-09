from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum
from typing import Any, Literal
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field


def utcnow() -> datetime:
    return datetime.now(UTC)


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:12]}"


class Visibility(StrEnum):
    private = "private"
    community = "community"
    public = "public"


class RunStatus(StrEnum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    cancelled = "cancelled"


class SearchType(StrEnum):
    text = "text"
    vector = "vector"
    hybrid = "hybrid"


class Workspace(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("ws"))
    name: str
    owner: str = "community"
    visibility: Visibility = Visibility.private
    created_at: datetime = Field(default_factory=utcnow)
    settings: dict[str, Any] = Field(default_factory=dict)


class Dataset(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("ds"))
    workspace_id: str
    name: str
    description: str = ""
    source_type: str
    schema_version: str = "v1"
    storage_path: str | None = None
    index_name: str = "diagnostik-documents-v1"
    created_at: datetime = Field(default_factory=utcnow)
    updated_at: datetime = Field(default_factory=utcnow)
    tags: list[str] = Field(default_factory=list)


class Connector(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    type: str
    version: str
    capabilities: list[str] = Field(default_factory=list)
    config_schema: dict[str, Any] = Field(default_factory=dict)
    compliance_profile: dict[str, Any] = Field(default_factory=dict)
    is_private: bool = False
    is_enabled: bool = True


class ConnectorRun(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("crun"))
    connector_name: str
    workspace_id: str
    dataset_id: str
    status: RunStatus = RunStatus.queued
    started_at: datetime | None = None
    ended_at: datetime | None = None
    records_read: int = 0
    records_written: int = 0
    errors_count: int = 0
    logs_path: str | None = None


class PipelineStep(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    type: Literal["validation", "transform", "enrichment", "embedding", "indexing"]
    model: str | None = None
    index: str | None = None
    config: dict[str, Any] = Field(default_factory=dict)


class Pipeline(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("pipe"))
    name: str
    steps: list[PipelineStep]
    input_dataset_id: str | None = None
    output_dataset_id: str | None = None
    schedule: str | None = None
    status: str = "draft"


class PipelineRun(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("prun"))
    pipeline_id: str
    status: RunStatus = RunStatus.queued
    started_at: datetime | None = None
    ended_at: datetime | None = None
    metrics: dict[str, Any] = Field(default_factory=dict)
    artifacts: list[str] = Field(default_factory=list)


class Document(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("doc"))
    dataset_id: str
    source_id: str
    title: str = ""
    text: str
    metadata: dict[str, Any] = Field(default_factory=dict)
    language: str = "unknown"
    created_at: datetime = Field(default_factory=utcnow)
    updated_at: datetime = Field(default_factory=utcnow)
    raw_path: str | None = None
    processed_path: str | None = None
    embedding_ids: list[str] = Field(default_factory=list)


class Artifact(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("art"))
    dataset_id: str
    type: Literal["raw", "processed", "embedding", "index", "model_output", "report"]
    path: str
    checksum: str
    mime_type: str
    created_at: datetime = Field(default_factory=utcnow)


class EmbeddingRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(default_factory=lambda: new_id("emb"))
    document_id: str
    model_name: str
    model_version: str
    vector: list[float]
    dimension: int
    created_at: datetime = Field(default_factory=utcnow)


class SearchQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    query: str
    dataset_ids: list[str] = Field(default_factory=list)
    filters: dict[str, Any] = Field(default_factory=dict)
    search_type: SearchType = SearchType.text
    limit: int = Field(default=10, ge=1, le=100)
    rerank: bool = False
    workspace_id: str
    alpha: float = Field(default=0.5, ge=0.0, le=1.0)


class SearchResult(BaseModel):
    document_id: str
    dataset_id: str
    title: str
    text: str
    score: float
    metadata: dict[str, Any] = Field(default_factory=dict)
