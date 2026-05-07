#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# update-checksums.sh — recalcule les SHA256 des manifests Ansible
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/update-checksums.sh
#         make checksums
#
# Ce script télécharge les manifests épinglés dans vars/main.yml et calcule
# leurs SHA256, puis met à jour le fichier en place.
# À exécuter :
#   - avant tout déploiement sur un nouveau cluster
#   - après chaque upgrade de version des manifests
#   - en CI pour valider que les hashes ne sont pas obsolètes
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh introuvable"; exit 1; }
ensure_repo_root

VARS_FILE="ansible/roles/k8s-node-config/vars/main.yml"
TMPDIR="$(mktemp -d)"
# shellcheck disable=SC2064  # intentionnel : expansion immédiate pour capturer TMPDIR
trap "rm -rf ${TMPDIR}" EXIT

# Portabilité macOS / Linux
# SC2086 : $SED_I doit être un tableau pour éviter le word-splitting sur macOS ("sed -i ''")
if uname -s | grep -qi darwin; then
  SED_I=(sed -i "")    # macOS BSD sed requiert l'argument vide après -i
else
  SED_I=(sed -i)       # GNU sed n'a pas besoin d'argument après -i
fi

echo "==> Calcul des SHA256 des manifests Ansible épinglés..."
echo ""

# Lire les URLs depuis le fichier vars
LOCAL_PATH_URL=$(grep "local_path_provisioner_url" "$VARS_FILE" | sed 's/.*: *"\(.*\)"/\1/')
INGRESS_URL=$(grep "ingress_nginx_url" "$VARS_FILE" | sed 's/.*: *"\(.*\)"/\1/')

# ── local-path-provisioner ───────────────────────────────────────────────────
echo "  Téléchargement local-path-provisioner..."
if curl -sLf --max-time 30 -o "${TMPDIR}/local-path.yaml" "${LOCAL_PATH_URL}"; then
  LOCAL_PATH_SHA=$(sha256sum "${TMPDIR}/local-path.yaml" | cut -d' ' -f1)
  "${SED_I[@]}" "s|local_path_provisioner_sha256: \".*\"|local_path_provisioner_sha256: \"${LOCAL_PATH_SHA}\"|" "$VARS_FILE"
  echo "  ✓ local-path-provisioner SHA256: ${LOCAL_PATH_SHA}"
else
  echo "  ✗ ERREUR : impossible de télécharger local-path-provisioner"
  echo "    URL : ${LOCAL_PATH_URL}"
  echo "    Vérifier la connexion réseau et la version épinglée."
  exit 1
fi

# ── ingress-nginx ────────────────────────────────────────────────────────────
echo "  Téléchargement ingress-nginx..."
if curl -sLf --max-time 30 -o "${TMPDIR}/ingress-nginx.yaml" "${INGRESS_URL}"; then
  INGRESS_SHA=$(sha256sum "${TMPDIR}/ingress-nginx.yaml" | cut -d' ' -f1)
  "${SED_I[@]}" "s|ingress_nginx_sha256: \".*\"|ingress_nginx_sha256: \"${INGRESS_SHA}\"|" "$VARS_FILE"
  echo "  ✓ ingress-nginx SHA256: ${INGRESS_SHA}"
else
  echo "  ✗ ERREUR : impossible de télécharger ingress-nginx"
  echo "    URL : ${INGRESS_URL}"
  exit 1
fi

echo ""
echo "✓ Hashes mis à jour dans ${VARS_FILE}"
echo ""
echo "  Commiter avec :"
echo "    git add ${VARS_FILE}"
echo "    git commit -m 'chore(ansible): refresh SHA256 checksums'"
