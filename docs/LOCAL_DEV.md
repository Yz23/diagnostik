# Local Development

```bash
cp .env.example .env
make app-install
make app-dev
```

In another shell:

```bash
make app-bootstrap-indexes
make app-ingest-mock
make app-run-pipeline
make app-search-demo
make app-test
```
