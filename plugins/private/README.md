# Private Plugins

This directory is reserved for local/private extensions and must not contain proprietary code in the public repository.

Recommended strategy:

- Keep private plugins in a separate private repository.
- Load them with `DIAGNOSTIK_PLUGIN_PATH=/path/to/private/plugins`.
- Never commit private datasets, credentials, connector configs, notebooks, or model artifacts.
- Do not publish sensitive or proprietary connector implementations in this public core.
