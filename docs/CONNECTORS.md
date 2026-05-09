# Connectors

Connectors implement `BaseConnector`:

- `validate_config`
- `dry_run`
- `fetch`
- `normalize`
- `publish`
- `get_compliance_profile`

Public connectors must be generic, rate-limited, documented, and safe for community use. Private connectors belong in a separate repository loaded through `DIAGNOSTIK_PLUGIN_PATH`.
