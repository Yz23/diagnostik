from __future__ import annotations

from diagnostik_common.schemas import Dataset, Document, EmbeddingRecord, Pipeline, PipelineRun, Workspace


class InMemoryStore:
    def __init__(self) -> None:
        self.workspaces: dict[str, Workspace] = {}
        self.datasets: dict[str, Dataset] = {}
        self.documents: dict[str, Document] = {}
        self.embeddings: dict[str, EmbeddingRecord] = {}
        self.pipelines: dict[str, Pipeline] = {}
        self.pipeline_runs: dict[str, PipelineRun] = {}

    def reset(self) -> None:
        self.workspaces.clear()
        self.datasets.clear()
        self.documents.clear()
        self.embeddings.clear()
        self.pipelines.clear()
        self.pipeline_runs.clear()


store = InMemoryStore()
