from __future__ import annotations

from fastapi import Header, HTTPException, status

from diagnostik_common.config import get_settings


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if settings.auth_mode == "none":
        return
    if settings.auth_mode == "api_key" and settings.api_key and x_api_key == settings.api_key:
        return
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
