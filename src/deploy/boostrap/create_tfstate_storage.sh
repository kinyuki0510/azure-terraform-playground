#!/bin/bash
# Usage: ./create_tfstate_storage.sh --env <dev|stg|prd>

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
    *)
      usage
      ;;
  esac
done

if [[ -z "${ENV_TYPE}" ]]; then
  usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/subscription_ids.sh"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: ${CONFIG_FILE} not found. Copy subscription_ids.sh.example and fill in values." >&2
  exit 1
fi
source "${CONFIG_FILE}"

# 誤った環境へのデプロイを防ぐガードレール
ACTUAL_SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
EXPECTED_SUBSCRIPTION_ID="${SUBSCRIPTION_IDS[$ENV_TYPE]}"

if [[ "${ACTUAL_SUBSCRIPTION_ID}" != "${EXPECTED_SUBSCRIPTION_ID}" ]]; then
  echo "subscription id is not match" >&2
  echo "  expected: ${EXPECTED_SUBSCRIPTION_ID}" >&2
  echo "  actual  : ${ACTUAL_SUBSCRIPTION_ID}" >&2
  exit 1
fi

declare -A RG_NAMES=(
  ["dev"]="atp-tfstate-dev-rg"
  ["stg"]="atp-tfstate-stg-rg"
  ["prd"]="atp-tfstate-prd-rg"
)

RG_NAME="${RG_NAMES[$ENV_TYPE]}"
# Storage Account名はグローバル一意のためサブスクリプションID先頭8文字をサフィックスに使用
SA_NAME="atptfstate${ENV_TYPE}${ACTUAL_SUBSCRIPTION_ID:0:8}"

az group create \
  --name "${RG_NAME}" \
  --location "japaneast"

az storage account create \
  --name "${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --location "japaneast" \
  --sku Standard_LRS

az storage container create \
  --name "tfstate" \
  --account-name "${SA_NAME}"

# tfstateの誤削除を防ぐためRGとStorage Account両方にロックをかける
az lock create \
  --name "lock-${RG_NAME}" \
  --resource-group "${RG_NAME}" \
  --lock-type CanNotDelete

az lock create \
  --name "lock-${SA_NAME}" \
  --resource-group "${RG_NAME}" \
  --resource-name "${SA_NAME}" \
  --resource-type "Microsoft.Storage/storageAccounts" \
  --lock-type CanNotDelete
