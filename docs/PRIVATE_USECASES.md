# Private Use Cases

Private use cases are external to the public repository.

Use a private repo for:

- private connectors;
- domain-specific pipelines;
- private datasets;
- specialized indexes;
- private dashboards;
- proprietary model or retrieval strategies.

The public core only provides generic extension points.

Load private extensions explicitly:

```bash
export DIAGNOSTIK_PLUGIN_PATH=/absolute/path/to/private/plugins
```

The loader expects plugin packages containing a `plugin.py` file with a `register(registry)` function.
