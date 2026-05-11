# Security Model

Security principles:

- No committed secrets.
- API key mode for POC, JWT/OIDC compatible design for MVP.
- Private plugins are loaded from external paths.
- Logs are JSON and must not include secrets.
- External AI providers are opt-in only.
- Workspace isolation is part of every query contract.
- Supply-chain checks should include gitleaks, trivy, pip-audit, bandit, and checkov.
