#!/bin/bash
# Verifies .env.example contains a placeholder, not a real password
set -euo pipefail
if grep -q "Admin_password_1!\|password123\|changeme" .env.example; then
    echo "ERROR: .env.example contains a weak or hardcoded password."
    echo "  Replace with : OPENSEARCH_INITIAL_ADMIN_PASSWORD=CHANGE_ME__min16chars_1Upper_1Symbol"
    exit 1
fi
if ! grep -q "CHANGE_ME" .env.example; then
    echo "ERROR: .env.example must contain CHANGE_ME as placeholder."
    exit 1
fi
if ! grep -q "LOGSTASH_VERSION" .env.example; then
    echo "ERROR: LOGSTASH_VERSION missing from .env.example"
    exit 1
fi
echo "✓ .env.example OK"
