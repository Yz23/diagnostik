from __future__ import annotations

from fastapi import APIRouter

from diagnostik_common.config import get_settings

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready"}


@router.get("/version")
def version() -> dict[str, str]:
    settings = get_settings()
    return {"version": settings.version, "service": "diagnostik-api"}
