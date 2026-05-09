#!/bin/bash
# Verifies .env.example contains a placeholder, not a real password
set -euo pipefail
for key in OPENSEARCH_INITIAL_ADMIN_PASSWORD KAFKA_ADMIN_PASSWORD KAFKA_CLIENT_PASSWORD DIAGNOSTIK_API_KEY; do
    if grep -Eq "^${key}=.+" .env.example; then
        echo "ERROR: .env.example must keep ${key} empty."
        exit 1
    fi
done
if ! grep -q "CHANGE_ME" .env.example; then
    echo "ERROR: .env.example must contain CHANGE_ME as placeholder."
    exit 1
fi
if ! grep -q "LOGSTASH_VERSION" .env.example; then
    echo "ERROR: LOGSTASH_VERSION missing from .env.example"
    exit 1
fi
echo "✓ .env.example OK"
