# Local Development

```bash
cp .env.example .env
make app-install
make app-dev
```

Default POC runtime:

```bash
DIAGNOSTIK_RUNTIME=memory
DIAGNOSTIK_AUTH_MODE=none
```

To test write/admin API key enforcement locally, set `DIAGNOSTIK_AUTH_MODE=api_key` and provide a local `DIAGNOSTIK_API_KEY` in `.env`.

In another shell:

```bash
make app-bootstrap-indexes
make app-ingest-mock
make app-run-pipeline
make app-search-demo
make app-test
```
