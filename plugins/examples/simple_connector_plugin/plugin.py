from __future__ import annotations

from typing import Any

from connectors.mock import MockConnector
from diagnostik_common.connectors import ConnectorDryRunResult, ConnectorRegistry


class SimpleExampleConnector(MockConnector):
    name = "simple_example"
    version = "1.0.0"
    connector_type = "example"
    capabilities = ["dry_run", "demo_data", "plugin"]

    def dry_run(self, config: dict[str, Any]) -> ConnectorDryRunResult:
        result = super().dry_run(config)
        result.connector_name = self.name
        return result


def register(registry: ConnectorRegistry) -> None:
    registry.register(SimpleExampleConnector())
