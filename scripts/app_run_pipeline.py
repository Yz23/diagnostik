from __future__ import annotations

import json
from http.client import HTTPConnection


def main() -> None:
    payload = json.dumps({"dataset_id": "demo"})
    connection = HTTPConnection("127.0.0.1", 8000, timeout=10)
    connection.request(
        "POST",
        "/pipelines/default_text_indexing/runs",
        body=payload,
        headers={"Content-Type": "application/json"},
    )
    response = connection.getresponse()
    print(response.read().decode())
    connection.close()


if __name__ == "__main__":
    main()
