from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException

from app.security.api_key import require_api_key
from app.services.runtime import registry
from diagnostik_common.connectors import ConnectorDryRunResult
from diagnostik_common.schemas import Connector, ConnectorRun, Dataset, RunStatus
from diagnostik_common.storage import store

router = APIRouter(tags=["connectors"])


@router.get("/connectors", response_model=list[Connector])
def list_connectors() -> list[Connector]:
    return registry.list()


@router.get("/connectors/{connector_name}", response_model=Connector)
def get_connector(connector_name: str) -> Connector:
    try:
        return registry.get(connector_name).manifest()
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/connectors/{connector_name}/dry-run", response_model=ConnectorDryRunResult)
def dry_run_connector(connector_name: str, config: dict[str, Any]) -> ConnectorDryRunResult:
    return registry.get(connector_name).dry_run(config)


@router.post("/connectors/{connector_name}/runs", response_model=ConnectorRun, dependencies=[Depends(require_api_key)])
def run_connector(connector_name: str, config: dict[str, Any]) -> ConnectorRun:
    connector = registry.get(connector_name)
    validated = connector.validate_config(config)
    workspace_id = validated.get("workspace_id", "default")
    dataset_id = validated.get("dataset_id", "demo")
    if workspace_id not in store.workspaces:
        from diagnostik_common.schemas import Workspace

        store.workspaces[workspace_id] = Workspace(id=workspace_id, name="Default", owner="community")
    if dataset_id not in store.datasets:
        store.datasets[dataset_id] = Dataset(
            id=dataset_id,
            workspace_id=workspace_id,
            name=f"{connector_name} demo dataset",
            source_type=connector.connector_type,
            tags=["demo", connector.connector_type],
        )
    run = ConnectorRun(
        connector_name=connector_name,
        workspace_id=workspace_id,
        dataset_id=dataset_id,
        status=RunStatus.running,
        started_at=datetime.now(UTC),
    )
    for raw_record in connector.fetch({**validated, "dataset_id": dataset_id}):
        run.records_read += 1
        document = connector.normalize(raw_record)
        store.documents[document.id] = connector.publish(document)
        run.records_written += 1
    run.status = RunStatus.succeeded
    run.ended_at = datetime.now(UTC)
    return run
