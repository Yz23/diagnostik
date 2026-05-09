#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/lib/common.sh — shared library for diagnostix
# ══════════════════════════════════════════════════════════════════════════════
# Single source of truth for:
#   - Provider list and mapping (DRY-1)
#   - Project root directory detection (SOLID-D)
#   - Common log/retry helpers (DRY-3)
#   - Provider capabilities (SOLID-L)
#   - Email/domain validation (SOLID-S)
#
# Usage in scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# ──────────────────────────────────────────────────────────────────────────────
# ── Idempotency guard — safe against double-source in the same shell ──────────
# Each script is invoked via `bash scripts/xxx.sh` (nouveau processus),
# so in practice this guard is only needed if someone manually sources
# multiple scripts in the same interactive shell.
[[ -n "${_INFRA_COMMON_LOADED:-}" ]] && return 0
readonly _INFRA_COMMON_LOADED=1

# ── Supported providers — SINGLE SOURCE OF TRUTH ─────────────────────────────
# Modify HERE to add a provider, not in the 4 separate scripts.
readonly SUPPORTED_PROVIDERS="gcp aws azure local"
readonly CLOUD_PROVIDERS="gcp aws azure"   # providers with external Ingress

# Provider → Terraform module mapping
provider_to_tf_module() {
  case "${1}" in
    gcp)   echo "gcp-gke"   ;;
    aws)   echo "aws-eks"   ;;
    azure) echo "azure-aks" ;;
    local) echo "local-k3s" ;;
    *)     echo ""          ;;
  esac
}

# Provider → Terraform backend file mapping
provider_to_backend_type() {
  case "${1}" in
    gcp)   echo "gcs"     ;;
    aws)   echo "s3"      ;;
    azure) echo "azurerm" ;;
    local) echo "http"    ;;
    *)     echo ""        ;;
  esac
}

# Provider capabilities (SOLID-L — Liskov: predictable behavior per provider)
provider_has_ingress()      { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }
provider_has_certmanager()  { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }
provider_has_dns_ingress()  { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }

# ── Project root detection (SOLID-D — no fragile relative paths) ──
find_repo_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  # Walk up until finding .git ou Makefile
  while [[ "${dir}" != "/" ]]; do
    if [[ -f "${dir}/Makefile" ]] && [[ -d "${dir}/scripts" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  # Fallback : current directory
  pwd
}

# Verifies the script is run from the project root
ensure_repo_root() {
  if [[ ! -f "Makefile" ]] || [[ ! -d "scripts" ]]; then
    echo "ERREUR : this script must be run from the project root."
    echo "  Current directory : $(pwd)"
    echo "  Exemple : cd /path/to/diagnostix && bash scripts/${BASH_SOURCE[1]##*/}"
    exit 1
  fi
}

# ── Validation des inputs (SOLID-S — single responsibility for validation) ─────────
validate_provider() {
  local provider="${1}"
  if [[ " ${SUPPORTED_PROVIDERS} " != *" ${provider} "* ]]; then
    log_err "Unknown provider : '${provider}'"
    log_err "  Supported providers : ${SUPPORTED_PROVIDERS}"
    return 1
  fi
}

validate_domain() {
  local domain="${1}"
  if [[ -z "${domain}" ]]; then
    log_err "Domain vide"
    return 1
  fi
  # Must contain at least one dot (required for Let's Encrypt)
  if ! echo "${domain}" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$'; then
    log_err "Invalid domain format : '${domain}'"
    log_err "  Domain must contain at least one dot (ex: mycompany.com)"
    return 1
  fi
}

validate_email() {
  local email="${1}"
  if [[ -z "${email}" ]]; then
    log_err "Email vide"
    return 1
  fi
  # Simplified RFC 5322
  if ! echo "${email}" | grep -qE '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'; then
    log_err "Invalid email format : '${email}'"
    log_err "  Exemple : ops@mycompany.com"
    return 1
  fi
}

# ── Helpers de log (visual consistency across all scripts) ─────────────────
log_step() { echo ""; echo "==> ${*}"; }
log_info()  { echo "    ${*}"; }
log_ok()    { echo "    ✓ ${*}"; }
log_warn()  { echo "    ⚠ ${*}"; }
log_err()   { echo "    ✗ ${*}" >&2; }
log_done()  { echo ""; echo "✓ ${*}"; }

# ── kubectl rollout wait — extracted from deploy.sh (DRY-3) ───────────────────────
# Usage : wait_rollout <resource-type/name> <timeout_seconds>
# Exemple : wait_rollout statefulset/zookeeper 180
wait_rollout() {
  local resource="${1}"
  local timeout_sec="${2:-180}"
  local ns="${NS:-data-platform}"
  log_info "Attente ${resource}..."
  kubectl -n "${ns}" rollout status "${resource}" --timeout="${timeout_sec}s"
  log_ok "${resource} ready"
}

# ── Retry helper ───────────────────────────────────────────────────────────────
# Usage : retry <max_attempts> <sleep_sec> <command...>
retry() {
  local max="${1}"; local sleep_sec="${2}"; shift 2
  local attempt=1
  until "$@"; do
    (( attempt++ ))
    [[ "${attempt}" -gt "${max}" ]] && { log_err "Failed after ${max} attempts : $*"; return 1; }
    log_info "Tentative ${attempt}/${max} dans ${sleep_sec}s..."
    sleep "${sleep_sec}"
  done
}

# ── .env loading (idempotent) ───────────────────────────────────────────────
load_env() {
  if [[ -f ".env" ]]; then
    set -a; source .env; set +a
  fi
}
