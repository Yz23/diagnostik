from __future__ import annotations

from fastapi import APIRouter

from app.services.runtime import default_pipeline_path, pipeline_engine
from diagnostik_common.schemas import Pipeline, PipelineRun
from diagnostik_common.storage import store

router = APIRouter(tags=["pipelines"])


@router.get("/pipelines", response_model=list[Pipeline])
def list_pipelines() -> list[Pipeline]:
    if not store.pipelines:
        pipeline = pipeline_engine.load_yaml(default_pipeline_path())
        pipeline.id = "default_text_indexing"
        store.pipelines[pipeline.id] = pipeline
    return list(store.pipelines.values())


@router.post("/pipelines", response_model=Pipeline)
def create_pipeline(pipeline: Pipeline) -> Pipeline:
    store.pipelines[pipeline.id] = pipeline
    return pipeline


@router.post("/pipelines/{pipeline_id}/runs", response_model=PipelineRun)
def run_pipeline(pipeline_id: str, payload: dict[str, str]) -> PipelineRun:
    pipeline = store.pipelines.get(pipeline_id)
    if pipeline is None:
        pipeline = pipeline_engine.load_yaml(default_pipeline_path())
        pipeline.id = pipeline_id
        store.pipelines[pipeline.id] = pipeline
    return pipeline_engine.run(pipeline, dataset_id=payload.get("dataset_id", "demo"))


@router.get("/pipeline-runs/{run_id}", response_model=PipelineRun)
def get_pipeline_run(run_id: str) -> PipelineRun:
    return store.pipeline_runs[run_id]
