from __future__ import annotations

from typing import Any


class EventPublisher:
    def publish(self, topic: str, event: dict[str, Any]) -> None:
        # POC no-op. Production implementations can wrap Kafka producers here.
        return None
