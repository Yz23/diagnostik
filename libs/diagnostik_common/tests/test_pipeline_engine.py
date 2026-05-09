from connectors.mock import MockConnector
from diagnostik_common.pipelines import PipelineEngine
from diagnostik_common.schemas import Dataset, Pipeline, PipelineStep, Workspace
from diagnostik_common.storage import InMemoryStore


def test_pipeline_engine_embeds_documents() -> None:
    store = InMemoryStore()
    store.workspaces["default"] = Workspace(id="default", name="Default")
    store.datasets["demo"] = Dataset(id="demo", workspace_id="default", name="Demo", source_type="mock")
    connector = MockConnector()
    for raw in connector.fetch({"dataset_id": "demo", "count": 2}):
        doc = connector.normalize(raw)
        store.documents[doc.id] = doc

    pipeline = Pipeline(
        id="default_text_indexing",
        name="default_text_indexing",
        steps=[
            PipelineStep(name="validate_document", type="validation"),
            PipelineStep(name="create_text_embedding", type="embedding"),
            PipelineStep(name="index_opensearch", type="indexing"),
        ],
    )
    run = PipelineEngine(store).run(pipeline, "demo")

    assert run.status == "succeeded"
    assert run.metrics["documents_embedded"] == 2
