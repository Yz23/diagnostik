from __future__ import annotations

import json
import urllib.request


def main() -> None:
    payload = json.dumps({"workspace_id": "default", "dataset_id": "demo", "count": 12, "domain": "cybersecurity"}).encode()
    request = urllib.request.Request(
        "http://127.0.0.1:8000/connectors/mock/runs",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        print(response.read().decode())


if __name__ == "__main__":
    main()
