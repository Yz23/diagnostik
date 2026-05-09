from diagnostik_common.schemas import Dataset, Document, Workspace


def test_core_schemas() -> None:
    workspace = Workspace(name="Demo", owner="community")
    dataset = Dataset(workspace_id=workspace.id, name="Demo dataset", source_type="mock")
    document = Document(dataset_id=dataset.id, source_id="src-1", title="Hello", text="World")

    assert workspace.id.startswith("ws_")
    assert dataset.workspace_id == workspace.id
    assert document.dataset_id == dataset.id
