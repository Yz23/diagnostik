from __future__ import annotations

from fastapi import APIRouter, HTTPException

from diagnostik_common.schemas import Workspace
from diagnostik_common.storage import store

router = APIRouter(prefix="/workspaces", tags=["workspaces"])


@router.post("", response_model=Workspace)
def create_workspace(workspace: Workspace) -> Workspace:
    store.workspaces[workspace.id] = workspace
    return workspace


@router.get("", response_model=list[Workspace])
def list_workspaces() -> list[Workspace]:
    return list(store.workspaces.values())


@router.get("/{workspace_id}", response_model=Workspace)
def get_workspace(workspace_id: str) -> Workspace:
    if workspace_id not in store.workspaces:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return store.workspaces[workspace_id]
