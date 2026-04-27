#!/bin/bash
# Usage: ./assign_roles.sh --env <dev|stg|prd> --assignee <account>

usage() {
  echo "error" >&2
  exit 1
}

while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
    --env)
      if [[ -z "${2}" ]]; then
        usage
      fi
      ENV_TYPE="${2}"
      if [[ ! "${ENV_TYPE}" =~ ^(dev|stg|prd)$ ]]; then
        usage
      fi
      shift 2
      ;;
    --assignee)
      if [[ -z "${2}" ]]; then
        usage
      fi
      ASSIGNEE="${2}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "${ENV_TYPE}" ]] || [[ -z "${ASSIGNEE}" ]]; then
  usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/subscription_ids.sh"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: ${CONFIG_FILE} not found. Copy subscription_ids.sh.example and fill in values." >&2
  exit 1
fi
source "${CONFIG_FILE}"

declare -A KV_NAMES=(
  ["dev"]="atp-dev-kv"
  ["stg"]="atp-stg-kv"
  ["prd"]="atp-prd-kv"
)

declare -A KV_RG_NAMES=(
  ["dev"]="atp-keyvault-dev-rg"
  ["stg"]="atp-keyvault-stg-rg"
  ["prd"]="atp-keyvault-prd-rg"
)

SUBSCRIPTION_ID="${SUBSCRIPTION_IDS[$ENV_TYPE]}"
KV_NAME="${KV_NAMES[$ENV_TYPE]}"
KV_RG_NAME="${KV_RG_NAMES[$ENV_TYPE]}"

SUBSCRIPTION_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
KV_SCOPE="${SUBSCRIPTION_SCOPE}/resourceGroups/${KV_RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"

az role assignment create \
  --assignee "${ASSIGNEE}" \
  --role "Owner" \
  --scope "${SUBSCRIPTION_SCOPE}"

az role assignment create \
  --assignee "${ASSIGNEE}" \
  --role "Key Vault Secrets Officer" \
  --scope "${KV_SCOPE}"
