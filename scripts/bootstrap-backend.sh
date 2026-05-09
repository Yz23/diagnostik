#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# bootstrap-backend.sh — initializes the Terraform remote state
# ══════════════════════════════════════════════════════════════════════════════
# Usage : bash scripts/bootstrap-backend.sh <PROVIDER> [OPTIONS]
# Providers: gcp | aws | azure | local
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
[ -f "${LIB}" ] && source "${LIB}" || { echo "ERREUR : scripts/lib/common.sh not found"; exit 1; }
ensure_repo_root

PROVIDER="${1:-}"

usage() {
  echo "Usage: bash scripts/bootstrap-backend.sh <PROVIDER>"
  echo "  gcp   : PROJECT_ID=my-project  REGION=eu-west1  bash $0 gcp"
  echo "  aws   : REGION=eu-west-1       bash $0 aws"
  echo "  azure : LOCATION=westeurope    bash $0 azure"
  echo "  local : BACKEND_URL=https://…  bash $0 local"
  exit 1
}

[ -z "${PROVIDER}" ] && usage
validate_provider "${PROVIDER}" || usage

BACKENDS_DIR="terraform/backends"
MODULE_DIR="terraform/modules"

# ── GCP ──────────────────────────────────────────────────────────────────────
bootstrap_gcp() {
  local project="${PROJECT_ID:?PROJECT_ID requis (ex: my-project)}"
  local region="${REGION:-europe-west1}"
  local bucket="${BUCKET:-${project}-tf-state}"
  local tfbackend="${BACKENDS_DIR}/gcp.tfbackend"

  log_step "[GCP] Bootstrap Terraform remote state"
  log_info "Project : ${project} | Region : ${region} | Bucket : ${bucket}"

  if ! gsutil ls "gs://${bucket}" &>/dev/null; then
    log_info "Creating GCS bucket gs://${bucket}..."
    gsutil mb -l "${region}" -p "${project}" "gs://${bucket}"
    gsutil versioning set on "gs://${bucket}"
    gsutil lifecycle set /dev/stdin "gs://${bucket}" << 'LC'
{"rule":[{"action":{"type":"Delete"},"condition":{"numNewerVersions":10,"isLive":false}}]}
LC
    log_ok "Bucket created (versioning + lifecycle 10 versions max)"
  else
    log_ok "Bucket gs://${bucket} already exists"
  fi

  printf 'bucket = "%s"\nprefix = "data-platform/gcp"\n' "${bucket}" > "${tfbackend}"
  log_ok "${tfbackend} generated"

  terraform -chdir="${MODULE_DIR}/gcp-gke" init \
    -backend-config="../../${tfbackend}" -reconfigure
  log_ok "Terraform GKE initialized with remote state"
}

# ── AWS ──────────────────────────────────────────────────────────────────────
bootstrap_aws() {
  local region="${REGION:-eu-west-1}"
  # FIX CRITIQUE : expansion correcte du compte AWS (|| dans sous-shell)
  local aws_account
  aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
  local bucket="${BUCKET:-${aws_account}-tf-state-dp}"
  local table="${TABLE:-tf-state-lock}"
  local tfbackend="${BACKENDS_DIR}/aws.tfbackend"

  log_step "[AWS] Bootstrap Terraform remote state"
  log_info "Region : ${region} | Bucket : ${bucket} | Table : ${table}"

  if ! aws s3 ls "s3://${bucket}" &>/dev/null; then
    log_info "Creating S3 bucket..."
    if [[ "${region}" == "us-east-1" ]]; then
      aws s3 mb "s3://${bucket}" --region "${region}"
    else
      aws s3 mb "s3://${bucket}" --region "${region}" \
        --create-bucket-configuration LocationConstraint="${region}"
    fi
    aws s3api put-bucket-versioning \
      --bucket "${bucket}" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
      --bucket "${bucket}" \
      --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    aws s3api put-public-access-block --bucket "${bucket}" \
      --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    log_ok "S3 bucket created (versioning + AES256 encryption + public access blocked)"
  else
    log_ok "Bucket s3://${bucket} already exists"
  fi

  if ! aws dynamodb describe-table --table-name "${table}" --region "${region}" &>/dev/null; then
    log_info "Creating DynamoDB table ${table}..."
    aws dynamodb create-table \
      --table-name "${table}" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST --region "${region}" > /dev/null
    log_ok "DynamoDB table created"
  else
    log_ok "DynamoDB table ${table} already exists"
  fi

  printf 'bucket         = "%s"\nkey            = "data-platform/aws/terraform.tfstate"\nregion         = "%s"\ndynamodb_table = "%s"\nencrypt        = true\n' \
    "${bucket}" "${region}" "${table}" > "${tfbackend}"
  log_ok "${tfbackend} generated"

  terraform -chdir="${MODULE_DIR}/aws-eks" init \
    -backend-config="../../${tfbackend}" -reconfigure
  log_ok "Terraform EKS initialized with remote state"
}

# ── Azure ─────────────────────────────────────────────────────────────────────
bootstrap_azure() {
  local location="${LOCATION:-westeurope}"
  local rg="${RESOURCE_GROUP:-rg-tfstate}"
  # Generate a unique name if not set (Storage Account : max 24 chars, alphanum seulement)
  local sa="${STORAGE_ACCOUNT:-tfstate$(date +%s | tail -c8)}"
  local container="tfstate"
  local tfbackend="${BACKENDS_DIR}/azure.tfbackend"

  log_step "[Azure] Bootstrap Terraform remote state"
  log_info "Location : ${location} | RG : ${rg} | Storage : ${sa}"

  if ! az group show --name "${rg}" &>/dev/null; then
    az group create --name "${rg}" --location "${location}" > /dev/null
    log_ok "Resource Group ${rg} created"
  else
    log_ok "Resource Group ${rg} already exists"
  fi

  if ! az storage account show --name "${sa}" --resource-group "${rg}" &>/dev/null; then
    az storage account create \
      --name "${sa}" --resource-group "${rg}" --location "${location}" \
      --sku Standard_LRS --kind StorageV2 \
      --https-only true --min-tls-version TLS1_2 > /dev/null
    log_ok "Storage Account created (HTTPS only, TLS 1.2)"
  else
    log_ok "Storage Account ${sa} already exists"
  fi

  local key
  key=$(az storage account keys list --resource-group "${rg}" \
    --account-name "${sa}" --query '[0].value' -o tsv)
  az storage container create --name "${container}" \
    --account-name "${sa}" --account-key "${key}" > /dev/null || true
  log_ok "Container ${container} ready"

  printf 'resource_group_name  = "%s"\nstorage_account_name = "%s"\ncontainer_name       = "%s"\nkey                  = "data-platform/azure/terraform.tfstate"\n' \
    "${rg}" "${sa}" "${container}" > "${tfbackend}"
  log_ok "${tfbackend} generated"

  terraform -chdir="${MODULE_DIR}/azure-aks" init \
    -backend-config="../../${tfbackend}" -reconfigure
  log_ok "Terraform AKS initialized with remote state"
}

# ── Local ─────────────────────────────────────────────────────────────────────
bootstrap_local() {
  local url="${BACKEND_URL:?BACKEND_URL requis (ex: https://backend.example.com)}"
  local tfbackend="${BACKENDS_DIR}/local.tfbackend"

  log_step "[Local/Proxmox] Bootstrap HTTP remote state"
  log_info "URL : ${url}"

  printf 'address        = "%s/data-platform/local"\nlock_address   = "%s/data-platform/local/lock"\nunlock_address = "%s/data-platform/local/lock"\n' \
    "${url}" "${url}" "${url}" > "${tfbackend}"
  log_ok "${tfbackend} generated"

  terraform -chdir="${MODULE_DIR}/local-k3s" init \
    -backend-config="../../${tfbackend}" -reconfigure
  log_ok "Terraform k3s initialized with HTTP remote state"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${PROVIDER}" in
  gcp)   bootstrap_gcp   ;;
  aws)   bootstrap_aws   ;;
  azure) bootstrap_azure ;;
  local) bootstrap_local ;;
esac

log_done "Terraform backend initialized — provider : ${PROVIDER}"
echo ""
echo "  Next step : PROVIDER=${PROVIDER} make provision"
echo "  Note : terraform/backends/${PROVIDER}.tfbackend is gitignored (do not commit)"
