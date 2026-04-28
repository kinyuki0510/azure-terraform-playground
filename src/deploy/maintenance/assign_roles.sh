#!/bin/bash
# Usage: ./assign_roles.sh --env <dev|stg|prd> --assignee <object-id>
# Run after account_setup.sh (requires App Configuration to exist)

set -euo pipefail

usage() {
  echo "Usage: $0 --env <dev|stg|prd> --assignee <object-id>" >&2
  exit 1
}

while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
    --env)
      if [[ -z "${2}" ]]; then usage; fi
      ENV_TYPE="${2}"
      if [[ ! "${ENV_TYPE}" =~ ^(dev|stg|prd)$ ]]; then usage; fi
      shift 2
      ;;
    --assignee)
      if [[ -z "${2}" ]]; then usage; fi
      ASSIGNEE="${2}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "${ENV_TYPE:-}" ]] || [[ -z "${ASSIGNEE:-}" ]]; then usage; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPCONFIG_NAME="atp-${ENV_TYPE}-appconfig"

# Load App Configuration and validate subscription
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../configuration.sh"

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

APPCONFIG_SCOPE="${SUBSCRIPTION_SCOPE}/resourceGroups/${KV_RG_NAME}/providers/Microsoft.AppConfiguration/configurationStores/${APPCONFIG_NAME}"

az role assignment create \
  --assignee "${ASSIGNEE}" \
  --role "App Configuration Data Reader" \
  --scope "${APPCONFIG_SCOPE}"
