#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# update-checksums.sh — recalculates SHA256 hashes of Ansible manifests
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/update-checksums.sh
#         make checksums
#
# This script downloads the pinned manifests from vars/main.yml and computes
# their SHA256 hashes, then updates the file in place.
# Run this:
#   - before any deployment on a new cluster
#   - after any manifest version upgrade
#   - in CI to verify the hashes are not stale
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh not found"; exit 1; }
ensure_repo_root

VARS_FILE="ansible/roles/k8s-node-config/vars/main.yml"
TMPDIR="$(mktemp -d)"
# shellcheck disable=SC2064  # intentional: immediate expansion to capture TMPDIR
trap "rm -rf ${TMPDIR}" EXIT

# macOS / Linux portability
# SC2086 : $SED_I must be an array to avoid word-splitting on macOS ("sed -i ''")
if uname -s | grep -qi darwin; then
  SED_I=(sed -i "")    # macOS BSD sed requires empty argument after -i
else
  SED_I=(sed -i)       # GNU sed does not need an argument after -i
fi

echo "==> Computing SHA256 hashes of pinned Ansible manifests..."
echo ""

# Lire les URLs depuis le fichier vars
LOCAL_PATH_URL=$(grep "local_path_provisioner_url" "$VARS_FILE" | sed 's/.*: *"\(.*\)"/\1/')
INGRESS_URL=$(grep "ingress_nginx_url" "$VARS_FILE" | sed 's/.*: *"\(.*\)"/\1/')

# ── local-path-provisioner ───────────────────────────────────────────────────
echo "  Downloading local-path-provisioner..."
if curl -sLf --max-time 30 -o "${TMPDIR}/local-path.yaml" "${LOCAL_PATH_URL}"; then
  LOCAL_PATH_SHA=$(sha256sum "${TMPDIR}/local-path.yaml" | cut -d' ' -f1)
  "${SED_I[@]}" "s|local_path_provisioner_sha256: \".*\"|local_path_provisioner_sha256: \"${LOCAL_PATH_SHA}\"|" "$VARS_FILE"
  echo "  ✓ local-path-provisioner SHA256: ${LOCAL_PATH_SHA}"
else
  echo "  ✗ ERROR: unable to download local-path-provisioner"
  echo "    URL : ${LOCAL_PATH_URL}"
  echo "    Check network connection and pinned version."
  exit 1
fi

# ── ingress-nginx ────────────────────────────────────────────────────────────
echo "  Downloading ingress-nginx..."
if curl -sLf --max-time 30 -o "${TMPDIR}/ingress-nginx.yaml" "${INGRESS_URL}"; then
  INGRESS_SHA=$(sha256sum "${TMPDIR}/ingress-nginx.yaml" | cut -d' ' -f1)
  "${SED_I[@]}" "s|ingress_nginx_sha256: \".*\"|ingress_nginx_sha256: \"${INGRESS_SHA}\"|" "$VARS_FILE"
  echo "  ✓ ingress-nginx SHA256: ${INGRESS_SHA}"
else
  echo "  ✗ ERROR: unable to download ingress-nginx"
  echo "    URL : ${INGRESS_URL}"
  exit 1
fi

echo ""
echo "✓ Hashes updated in ${VARS_FILE}"
echo ""
echo "  Commit with :"
echo "    git add ${VARS_FILE}"
echo "    git commit -m 'chore(ansible): refresh SHA256 checksums'"
