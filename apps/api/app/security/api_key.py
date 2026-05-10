from __future__ import annotations

from fastapi import Header, HTTPException, status

from diagnostik_common.config import AuthMode, get_settings


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if settings.auth_mode == AuthMode.none:
        return
    if settings.auth_mode == AuthMode.api_key:
        if not settings.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="DIAGNOSTIK_API_KEY is required when DIAGNOSTIK_AUTH_MODE=api_key",
            )
        if x_api_key == settings.api_key:
            return
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="Unsupported auth mode")
