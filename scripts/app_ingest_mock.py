from __future__ import annotations

import json
from http.client import HTTPConnection


def main() -> None:
    payload = json.dumps({"workspace_id": "default", "dataset_id": "demo", "count": 12, "domain": "cybersecurity"})
    connection = HTTPConnection("127.0.0.1", 8000, timeout=10)
    connection.request("POST", "/connectors/mock/runs", body=payload, headers={"Content-Type": "application/json"})
    response = connection.getresponse()
    print(response.read().decode())
    connection.close()


if __name__ == "__main__":
    main()
