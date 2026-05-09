from __future__ import annotations

from pathlib import Path
from typing import Any

import json


def load_index_template(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text())


def build_text_query(workspace_id: str, query: str, dataset_ids: list[str] | None = None) -> dict[str, Any]:
    filters: list[dict[str, Any]] = [{"term": {"workspace_id": workspace_id}}]
    if dataset_ids:
        filters.append({"terms": {"dataset_id": dataset_ids}})
    return {
        "query": {
            "bool": {
                "must": [{"multi_match": {"query": query, "fields": ["title^2", "text"]}}],
                "filter": filters,
            }
        }
    }
