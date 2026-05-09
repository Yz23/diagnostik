# Connectors

Public connectors must be generic, documented, rate-limited, and safe for community use.

This repository intentionally does not include private business connectors, sensitive datasets, or private-domain-specific collector logic. Private extensions should live in a separate repository and be loaded through `DIAGNOSTIK_PLUGIN_PATH`.

Included public connector scopes:

- `mock`: synthetic demo data.
- `file`: CSV, JSON, JSONL, TXT, Markdown imports.
- `api_generic`: simple HTTP APIs with explicit configuration.
- `rss`: public RSS feeds.
- `database`: read-only database scaffold.
- `web_public`: robots.txt-aware public web fetching only.
