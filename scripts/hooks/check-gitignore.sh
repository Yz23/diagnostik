#!/bin/bash
# Vérifie que .gitignore contient toutes les entrées de sécurité obligatoires.
# Hook pre-commit — appelé automatiquement avant chaque git commit.
set -euo pipefail

REQUIRED=(
  ".env" "kubeconfig" ".ansible/" ".terraform/"
  "terraform.tfstate" "*.tfvars" "*.tfbackend"
  "ingress-domain.yaml" "cluster-issuer-configured.yaml"
)

FAIL=0
for entry in "${REQUIRED[@]}"; do
  if ! grep -q "${entry}" .gitignore 2>/dev/null; then
    echo "ERREUR : .gitignore manque l'entrée : ${entry}"
    FAIL=1
  fi
done

[ "$FAIL" -eq 0 ] && echo "✓ .gitignore OK" || exit 1
