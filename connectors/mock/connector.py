from __future__ import annotations

from collections.abc import Iterable
from typing import Any

from diagnostik_common.connectors import BaseConnector, ConnectorDryRunResult
from diagnostik_common.schemas import Document


class MockConnector(BaseConnector):
    name = "mock"
    version = "1.0.0"
    connector_type = "mock"
    capabilities = ["batch", "dry_run", "demo_data"]

    domains = {
        "cybersecurity": ["zero trust", "incident response", "ai governance"],
        "health": ["clinical notes", "care pathways", "privacy"],
        "finance": ["risk scoring", "market analysis", "fraud detection"],
        "education": ["learning analytics", "curriculum", "assessment"],
        "sport": ["performance", "match analysis", "training"],
        "culture": ["archives", "exhibitions", "public collections"],
    }

    def validate_config(self, config: dict[str, Any]) -> dict[str, Any]:
        count = int(config.get("count", 12))
        if count < 1 or count > 500:
            raise ValueError("count must be between 1 and 500")
        return {
            "dataset_id": config.get("dataset_id", "demo"),
            "count": count,
            "domain": config.get("domain", "cybersecurity"),
            "language": config.get("language", "en"),
        }

    def dry_run(self, config: dict[str, Any]) -> ConnectorDryRunResult:
        validated = self.validate_config(config)
        return ConnectorDryRunResult(ok=True, connector_name=self.name, records_previewed=min(validated["count"], 5))

    def fetch(self, config: dict[str, Any], cursor: str | None = None) -> Iterable[dict[str, Any]]:
        validated = self.validate_config(config)
        domain = validated["domain"]
        topics = self.domains.get(domain, self.domains["cybersecurity"])
        for index in range(validated["count"]):
            topic = topics[index % len(topics)]
            yield {
                "id": f"mock-{domain}-{index}",
                "dataset_id": validated["dataset_id"],
                "title": f"{domain.title()} signal {index + 1}",
                "text": f"This community demo document covers {topic} for open data and AI exploration.",
                "metadata": {"domain": domain, "tags": [domain, topic.replace(" ", "-"), "demo"]},
                "language": validated["language"],
            }

    def normalize(self, raw_record: dict[str, Any]) -> Document:
        return Document(
            dataset_id=raw_record["dataset_id"],
            source_id=raw_record["id"],
            title=raw_record["title"],
            text=raw_record["text"],
            metadata=raw_record.get("metadata", {}),
            language=raw_record.get("language", "en"),
        )

    def get_compliance_profile(self) -> dict[str, Any]:
        return {
            "public_safe": True,
            "contains_personal_data": False,
            "requires_auth": False,
            "external_network": False,
            "notes": "Synthetic demo data only.",
        }
