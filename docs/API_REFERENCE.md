# API Reference

Initial endpoints:

- `GET /health`
- `GET /ready`
- `GET /version`
- `GET /connectors`
- `POST /connectors/mock/runs`
- `POST /datasets`
- `GET /datasets`
- `POST /documents`
- `POST /pipelines/{pipeline_id}/runs`
- `POST /search/text`
- `POST /search/vector`
- `POST /search/hybrid`
- `GET /admin/stats`
- `POST /admin/indexes/bootstrap`

When `DIAGNOSTIK_AUTH_MODE=api_key`, write and admin endpoints require:

```bash
X-API-Key: $DIAGNOSTIK_API_KEY
```

Example:

```bash
curl http://localhost:8000/health
```
