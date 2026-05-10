from __future__ import annotations

import json
import os
from http.client import HTTPConnection


def headers() -> dict[str, str]:
    request_headers = {"Content-Type": "application/json"}
    if api_key := os.getenv("DIAGNOSTIK_API_KEY"):
        request_headers["X-API-Key"] = api_key
    return request_headers


def main() -> None:
    payload = json.dumps({"dataset_id": "demo"})
    connection = HTTPConnection("127.0.0.1", 8000, timeout=10)
    connection.request(
        "POST",
        "/pipelines/default_text_indexing/runs",
        body=payload,
        headers=headers(),
    )
    response = connection.getresponse()
    print(response.read().decode())
    connection.close()


if __name__ == "__main__":
    main()
