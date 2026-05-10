#!/bin/bash
# Verifies .env.example contains empty secret fields, not default passwords.
set -euo pipefail
for key in OPENSEARCH_INITIAL_ADMIN_PASSWORD KAFKA_ADMIN_PASSWORD KAFKA_CLIENT_PASSWORD DIAGNOSTIK_API_KEY; do
    if grep -Eq "^${key}=.+" .env.example; then
        echo "ERROR: .env.example must keep ${key} empty."
        exit 1
    fi
done
if ! grep -q "DIAGNOSTIK_RUNTIME=memory" .env.example; then
    echo "ERROR: DIAGNOSTIK_RUNTIME=memory missing from .env.example"
    exit 1
fi
echo "✓ .env.example OK"
