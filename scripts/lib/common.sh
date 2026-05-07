#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/lib/common.sh — bibliothèque partagée diagnostix
# ══════════════════════════════════════════════════════════════════════════════
# Source unique de vérité pour :
#   - Liste et mapping des providers (DRY-1)
#   - Détection du répertoire racine du projet (SOLID-D)
#   - Helpers log/retry communs (DRY-3)
#   - Capacités par provider (SOLID-L)
#   - Validation email/domaine (SOLID-S)
#
# Usage dans les scripts :
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# ──────────────────────────────────────────────────────────────────────────────
# ── Garde idempotente — safe contre double-source dans le même shell ──────────
# Chaque script est invoqué via `bash scripts/xxx.sh` (nouveau processus),
# donc en pratique ce guard n'est nécessaire que si quelqu'un source manuellement
# plusieurs scripts dans le même shell interactif.
[[ -n "${_INFRA_COMMON_LOADED:-}" ]] && return 0
readonly _INFRA_COMMON_LOADED=1

# ── Providers supportés — SOURCE UNIQUE DE VÉRITÉ ─────────────────────────────
# Modifier ICI pour ajouter un provider, pas dans les 4 scripts séparés.
readonly SUPPORTED_PROVIDERS="gcp aws azure local"
readonly CLOUD_PROVIDERS="gcp aws azure"   # providers avec Ingress externe

# Mapping provider → module Terraform
provider_to_tf_module() {
  case "${1}" in
    gcp)   echo "gcp-gke"   ;;
    aws)   echo "aws-eks"   ;;
    azure) echo "azure-aks" ;;
    local) echo "local-k3s" ;;
    *)     echo ""          ;;
  esac
}

# Mapping provider → fichier backend Terraform
provider_to_backend_type() {
  case "${1}" in
    gcp)   echo "gcs"     ;;
    aws)   echo "s3"      ;;
    azure) echo "azurerm" ;;
    local) echo "http"    ;;
    *)     echo ""        ;;
  esac
}

# Capacités provider (SOLID-L — Liskov : comportement prévisible par provider)
provider_has_ingress()      { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }
provider_has_certmanager()  { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }
provider_has_dns_ingress()  { [[ " ${CLOUD_PROVIDERS} " == *" ${1} "* ]]; }

# ── Détection racine du projet (SOLID-D — pas de chemins relatifs fragiles) ──
find_repo_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  # Remonter jusqu'à trouver .git ou Makefile
  while [[ "${dir}" != "/" ]]; do
    if [[ -f "${dir}/Makefile" ]] && [[ -d "${dir}/scripts" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  # Fallback : répertoire courant
  pwd
}

# Vérifie que le script est exécuté depuis la racine du projet
ensure_repo_root() {
  if [[ ! -f "Makefile" ]] || [[ ! -d "scripts" ]]; then
    echo "ERREUR : ce script doit être exécuté depuis la racine du projet."
    echo "  Répertoire courant : $(pwd)"
    echo "  Exemple : cd /path/to/diagnostix && bash scripts/${BASH_SOURCE[1]##*/}"
    exit 1
  fi
}

# ── Validation des inputs (SOLID-S — responsabilité unique validation) ─────────
validate_provider() {
  local provider="${1}"
  if [[ " ${SUPPORTED_PROVIDERS} " != *" ${provider} "* ]]; then
    log_err "Provider inconnu : '${provider}'"
    log_err "  Providers supportés : ${SUPPORTED_PROVIDERS}"
    return 1
  fi
}

validate_domain() {
  local domain="${1}"
  if [[ -z "${domain}" ]]; then
    log_err "Domaine vide"
    return 1
  fi
  # Doit contenir au moins un point (requis pour Let's Encrypt)
  if ! echo "${domain}" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$'; then
    log_err "Format domaine invalide : '${domain}'"
    log_err "  Le domaine doit contenir au moins un point (ex: mycompany.com)"
    return 1
  fi
}

validate_email() {
  local email="${1}"
  if [[ -z "${email}" ]]; then
    log_err "Email vide"
    return 1
  fi
  # RFC 5322 simplifié
  if ! echo "${email}" | grep -qE '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'; then
    log_err "Format email invalide : '${email}'"
    log_err "  Exemple : ops@mycompany.com"
    return 1
  fi
}

# ── Helpers de log (cohérence visuelle dans tous les scripts) ─────────────────
log_step() { echo ""; echo "==> ${*}"; }
log_info()  { echo "    ${*}"; }
log_ok()    { echo "    ✓ ${*}"; }
log_warn()  { echo "    ⚠ ${*}"; }
log_err()   { echo "    ✗ ${*}" >&2; }
log_done()  { echo ""; echo "✓ ${*}"; }

# ── kubectl rollout wait — extrait de deploy.sh (DRY-3) ───────────────────────
# Usage : wait_rollout <resource-type/name> <timeout_seconds>
# Exemple : wait_rollout statefulset/zookeeper 180
wait_rollout() {
  local resource="${1}"
  local timeout_sec="${2:-180}"
  local ns="${NS:-data-platform}"
  log_info "Attente ${resource}..."
  kubectl -n "${ns}" rollout status "${resource}" --timeout="${timeout_sec}s"
  log_ok "${resource} prêt"
}

# ── Retry helper ───────────────────────────────────────────────────────────────
# Usage : retry <max_attempts> <sleep_sec> <command...>
retry() {
  local max="${1}"; local sleep_sec="${2}"; shift 2
  local attempt=1
  until "$@"; do
    (( attempt++ ))
    [[ "${attempt}" -gt "${max}" ]] && { log_err "Echec après ${max} tentatives : $*"; return 1; }
    log_info "Tentative ${attempt}/${max} dans ${sleep_sec}s..."
    sleep "${sleep_sec}"
  done
}

# ── Chargement .env (idempotent) ───────────────────────────────────────────────
load_env() {
  if [[ -f ".env" ]]; then
    set -a; source .env; set +a
  fi
}
