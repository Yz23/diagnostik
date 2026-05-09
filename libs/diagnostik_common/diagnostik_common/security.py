from __future__ import annotations

from hashlib import sha256


def mask_secret(value: str | None) -> str | None:
    if not value:
        return value
    return f"sha256:{sha256(value.encode()).hexdigest()[:10]}"
