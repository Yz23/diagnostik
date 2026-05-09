#!/bin/bash
# Verifies .gitignore contains all required security entries.
# pre-commit hook — called automatically before each git commit.
set -euo pipefail

REQUIRED=(
  ".env" "kubeconfig" ".ansible/" ".terraform/"
  "terraform.tfstate" "*.tfvars" "*.tfbackend"
  "ingress-domain.yaml" "cluster-issuer-configured.yaml"
)

FAIL=0
for entry in "${REQUIRED[@]}"; do
  if ! grep -q "${entry}" .gitignore 2>/dev/null; then
    echo "ERROR: .gitignore is missing required entry : ${entry}"
    FAIL=1
  fi
done

[ "$FAIL" -eq 0 ] && echo "✓ .gitignore OK" || exit 1
