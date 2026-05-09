# Plugin SDK

Plugin authors implement `BaseConnector` and expose a `register(registry)` function.

Private plugins should be loaded from `DIAGNOSTIK_PLUGIN_PATH` and kept outside this public repository.
