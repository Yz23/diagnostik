from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml  # type: ignore[import-untyped]

from diagnostik_common.embedding import EmbeddingProvider, MockEmbeddingProvider
from diagnostik_common.errors import PipelineError
from diagnostik_common.schemas import EmbeddingRecord, Pipeline, PipelineRun, RunStatus, utcnow
from diagnostik_common.storage import InMemoryStore


class PipelineEngine:
    def __init__(self, store: InMemoryStore, embedding_provider: EmbeddingProvider | None = None) -> None:
        self.store = store
        self.embedding_provider = embedding_provider or MockEmbeddingProvider()

    def load_yaml(self, path: str | Path) -> Pipeline:
        data: dict[str, Any] = yaml.safe_load(Path(path).read_text()) or {}
        return Pipeline(
            name=data["name"],
            steps=data["steps"],
            status="active",
        )

    def run(self, pipeline: Pipeline, dataset_id: str) -> PipelineRun:
        run = PipelineRun(pipeline_id=pipeline.id, status=RunStatus.running, started_at=utcnow())
        self.store.pipeline_runs[run.id] = run
        documents = [doc for doc in self.store.documents.values() if doc.dataset_id == dataset_id]
        metrics = {"documents_seen": len(documents), "documents_embedded": 0, "documents_indexed": 0}
        try:
            for step in pipeline.steps:
                if step.type == "validation":
                    for document in documents:
                        if not document.text.strip():
                            raise PipelineError(f"Document {document.id} has empty text")
                elif step.type == "transform":
                    for document in documents:
                        document.text = " ".join(document.text.split())
                        document.title = document.title.strip()
                elif step.type == "embedding":
                    for document in documents:
                        vector = self.embedding_provider.embed_text(document.text)
                        embedding = EmbeddingRecord(
                            document_id=document.id,
                            model_name=self.embedding_provider.model_name,
                            model_version=self.embedding_provider.model_version,
                            vector=vector,
                            dimension=len(vector),
                        )
                        self.store.embeddings[embedding.id] = embedding
                        document.embedding_ids.append(embedding.id)
                        metrics["documents_embedded"] += 1
                elif step.type == "indexing":
                    metrics["documents_indexed"] += len(documents)
                elif step.type == "enrichment":
                    for document in documents:
                        document.metadata["enriched"] = True
                else:
                    raise PipelineError(f"Unsupported pipeline step: {step.type}")
            run.status = RunStatus.succeeded
        except Exception as exc:
            run.status = RunStatus.failed
            run.metrics["error"] = str(exc)
            raise
        finally:
            run.ended_at = utcnow()
            run.metrics.update(metrics)
        return run
