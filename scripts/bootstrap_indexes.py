from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    templates = sorted((root / "config" / "opensearch" / "index_templates").glob("*.json"))
    print(json.dumps({
        "status": "ok",
        "mode": "dry-run",
        "templates": [template.name for template in templates],
        "aliases": [
            "diagnostik-documents-read",
            "diagnostik-documents-write",
            "diagnostik-documents-current",
        ],
    }))


if __name__ == "__main__":
    main()
