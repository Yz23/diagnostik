# Plugin SDK

Plugins can register connectors or pipeline steps without changing the public core.

Private plugins should be loaded from:

```bash
DIAGNOSTIK_PLUGIN_PATH=/path/to/private/plugins
```

Never commit private plugins, datasets, secrets, or proprietary configs to the public repository.
