from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Iterable
from typing import Any

from pydantic import BaseModel

from diagnostik_common.schemas import Connector, Document


class ConnectorDryRunResult(BaseModel):
    ok: bool
    connector_name: str
    records_previewed: int = 0
    warnings: list[str] = []


class BaseConnector(ABC):
    name: str
    version: str
    connector_type: str
    capabilities: list[str] = []
    is_private: bool = False

    @abstractmethod
    def validate_config(self, config: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    @abstractmethod
    def dry_run(self, config: dict[str, Any]) -> ConnectorDryRunResult:
        raise NotImplementedError

    @abstractmethod
    def fetch(self, config: dict[str, Any], cursor: str | None = None) -> Iterable[dict[str, Any]]:
        raise NotImplementedError

    @abstractmethod
    def normalize(self, raw_record: dict[str, Any]) -> Document:
        raise NotImplementedError

    def publish(self, document: Document) -> Document:
        return document

    def get_compliance_profile(self) -> dict[str, Any]:
        return {"public_safe": True, "requires_auth": False, "respects_rate_limits": True}

    def manifest(self) -> Connector:
        return Connector(
            name=self.name,
            type=self.connector_type,
            version=self.version,
            capabilities=self.capabilities,
            config_schema={},
            compliance_profile=self.get_compliance_profile(),
            is_private=self.is_private,
            is_enabled=True,
        )


class ConnectorRegistry:
    def __init__(self) -> None:
        self._connectors: dict[str, BaseConnector] = {}

    def register(self, connector: BaseConnector) -> None:
        self._connectors[connector.name] = connector

    def list(self) -> list[Connector]:
        return [connector.manifest() for connector in self._connectors.values()]

    def get(self, name: str) -> BaseConnector:
        if name not in self._connectors:
            raise KeyError(f"Unknown connector: {name}")
        return self._connectors[name]
