from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.security.api_key import require_api_key
from diagnostik_common.schemas import Dataset, Document
from diagnostik_common.storage import store

router = APIRouter(tags=["datasets", "documents"])


@router.post("/datasets", response_model=Dataset, dependencies=[Depends(require_api_key)])
def create_dataset(dataset: Dataset) -> Dataset:
    store.datasets[dataset.id] = dataset
    return dataset


@router.get("/datasets", response_model=list[Dataset])
def list_datasets(workspace_id: str | None = None) -> list[Dataset]:
    datasets = list(store.datasets.values())
    if workspace_id:
        datasets = [dataset for dataset in datasets if dataset.workspace_id == workspace_id]
    return datasets


@router.get("/datasets/{dataset_id}", response_model=Dataset)
def get_dataset(dataset_id: str) -> Dataset:
    if dataset_id not in store.datasets:
        raise HTTPException(status_code=404, detail="Dataset not found")
    return store.datasets[dataset_id]


@router.post("/documents", response_model=Document, dependencies=[Depends(require_api_key)])
def create_document(document: Document) -> Document:
    store.documents[document.id] = document
    return document


@router.get("/documents/{document_id}", response_model=Document)
def get_document(document_id: str) -> Document:
    if document_id not in store.documents:
        raise HTTPException(status_code=404, detail="Document not found")
    return store.documents[document_id]


@router.get("/datasets/{dataset_id}/documents", response_model=list[Document])
def list_documents(dataset_id: str) -> list[Document]:
    return [document for document in store.documents.values() if document.dataset_id == dataset_id]
