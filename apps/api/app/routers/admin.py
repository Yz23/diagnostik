from __future__ import annotations

from fastapi import APIRouter, Depends

from app.security.api_key import require_api_key
from diagnostik_common.storage import store

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_api_key)])


@router.get("/stats")
def get_stats() -> dict[str, int]:
    return {
        "workspaces": len(store.workspaces),
        "datasets": len(store.datasets),
        "documents": len(store.documents),
        "embeddings": len(store.embeddings),
        "pipelines": len(store.pipelines),
        "pipeline_runs": len(store.pipeline_runs),
    }


@router.post("/indexes/bootstrap")
def bootstrap_indexes() -> dict[str, str]:
    return {"status": "accepted", "mode": "poc-dry-run"}
