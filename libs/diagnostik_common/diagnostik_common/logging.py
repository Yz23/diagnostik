from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname.lower(),
            "service": getattr(record, "service", "diagnostik"),
            "environment": getattr(record, "environment", "local"),
            "request_id": getattr(record, "request_id", None),
            "workspace_id": getattr(record, "workspace_id", None),
            "dataset_id": getattr(record, "dataset_id", None),
            "run_id": getattr(record, "run_id", None),
            "event_type": getattr(record, "event_type", record.getMessage()),
            "status": getattr(record, "status", None),
            "duration_ms": getattr(record, "duration_ms", None),
            "error_class": getattr(record, "error_class", None),
            "error_message": getattr(record, "error_message", None),
            "message": record.getMessage(),
        }
        return json.dumps({k: v for k, v in payload.items() if v is not None}, default=str)


def configure_logging(service: str = "diagnostik", environment: str = "local") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(logging.INFO)
    logging.LoggerAdapter(logging.getLogger(service), {"service": service, "environment": environment})


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
