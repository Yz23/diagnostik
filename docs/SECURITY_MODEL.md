# Security Model

Security principles:

- No committed secrets.
- API key mode for POC, JWT/OIDC compatible design for MVP.
- With `DIAGNOSTIK_AUTH_MODE=api_key`, write and admin endpoints require `X-API-Key: $DIAGNOSTIK_API_KEY`.
- `DIAGNOSTIK_API_KEY` must be set outside Git; `.env.example` intentionally keeps it empty.
- Private plugins are loaded from external paths.
- Logs are JSON and must not include secrets.
- External AI providers are opt-in only.
- Workspace isolation is part of every query contract.
- Supply-chain checks should include gitleaks, trivy, pip-audit, bandit, and checkov.
