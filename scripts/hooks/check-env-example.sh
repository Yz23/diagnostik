#!/bin/bash
# Vérifie que .env.example contient un placeholder, pas un vrai mot de passe
set -euo pipefail
if grep -q "Admin_password_1!\|password123\|changeme" .env.example; then
    echo "ERREUR : .env.example contient un mot de passe faible ou hardcodé."
    echo "  Remplacer par : OPENSEARCH_INITIAL_ADMIN_PASSWORD=CHANGE_ME__min16chars_1Upper_1Symbol"
    exit 1
fi
if ! grep -q "CHANGE_ME" .env.example; then
    echo "ERREUR : .env.example doit contenir CHANGE_ME comme placeholder."
    exit 1
fi
if ! grep -q "LOGSTASH_VERSION" .env.example; then
    echo "ERREUR : LOGSTASH_VERSION absent de .env.example"
    exit 1
fi
echo "✓ .env.example OK"
