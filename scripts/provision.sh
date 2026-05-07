#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# provision.sh — terraform apply avec remote state automatique
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/provision.sh [PROVIDER]
#         PROVIDER : gcp | aws | azure | local  (défaut : gcp)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh introuvable"; exit 1; }
ensure_repo_root
load_env

PROVIDER="${1:-${PROVIDER:-gcp}}"
validate_provider "${PROVIDER}" || exit 1

# ── Source unique de vérité : provider_to_tf_module() (FIX B2 — DRY) ─────────
MODULE="$(provider_to_tf_module "${PROVIDER}")"
if [[ -z "${MODULE}" ]]; then
  log_err "Mapping provider→module introuvable pour '${PROVIDER}'"
  exit 1
fi

BACKEND_FILE="terraform/backends/${PROVIDER}.tfbackend"

log_step "Provision — provider : ${PROVIDER} | module : ${MODULE}"

if [[ -f "${BACKEND_FILE}" ]]; then
  log_info "Remote state backend : ${BACKEND_FILE}"
  terraform -chdir="terraform/modules/${MODULE}" init \
    -backend-config="../../${BACKEND_FILE}" -reconfigure
else
  log_warn "Aucun backend configuré — state local (dev seulement)"
  log_warn "  Pour activer le remote state : make bootstrap-backend PROVIDER=${PROVIDER}"
  terraform -chdir="terraform/modules/${MODULE}" init -backend=false
fi

terraform -chdir="terraform/modules/${MODULE}" apply

log_done "Provision terminé — provider : ${PROVIDER}"
