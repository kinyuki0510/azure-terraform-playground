#!/bin/bash

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


if [[ -z $ENV_TYPE ]]; then
  usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/subscription_ids.sh"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: ${CONFIG_FILE} not found. Copy subscription_ids.sh.example and fill in values." >&2
  exit 1
fi
source "${CONFIG_FILE}"

ACTUAL_SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
EXPECTED_SUBSCRIPTION_ID="${SUBSCRIPTION_IDS[$ENV_TYPE]}"

if [[ "${ACTUAL_SUBSCRIPTION_ID}" != "${EXPECTED_SUBSCRIPTION_ID}" ]]; then
  echo "subscription id is not match" >&2
  echo "  expected: ${EXPECTED_SUBSCRIPTION_ID}" >&2
  echo "  actual  : ${ACTUAL_SUBSCRIPTION_ID}" >&2
  exit 1
fi

function register_providers() {
  local _providers=(
    "Microsoft.KeyVault"
    "Microsoft.App"
    "Microsoft.DBforPostgreSQL"
    "Microsoft.Storage"
    "Microsoft.Web"
    "Microsoft.Network"
  )

  for _provider in "${_providers[@]}"; do
    az provider register --namespace "${_provider}"
  done

  echo "provider registration started. may take a few minutes to complete."
}

function create_keyvault() {
  local _vault="${1}"
  local _resource_group="${2}"

  az group create \
    --name "${_resource_group}" \
    --location "japaneast"

  az keyvault create \
    --name "${_vault}" \
    --resource-group "${_resource_group}" \
    --location "japaneast"
}

function set_keyvault_secret() {
  local _vault="${1}"
  local _key="${2}"
  local _value="${3}"

  az keyvault secret set \
    --vault-name "${_vault}" \
    --name "${_key}" \
    --value "${_value}"
}

if [[ $ENV_TYPE == "dev" ]]; then
  KV_NAME="atp-dev-kv"
  RG_NAME="atp-keyvault-dev-rg"

  register_providers
  create_keyvault "${KV_NAME}" "${RG_NAME}"

  set_keyvault_secret "${KV_NAME}" "account-envtype" "dev"

  read -rsp "pg-admin-password を入力してください: " _pg_password
  echo
  set_keyvault_secret "${KV_NAME}" "pg-admin-password" "${_pg_password}"
  unset _pg_password

  set_keyvault_secret "${KV_NAME}" "account-envtype" "dev"


elif [[ $ENV_TYPE == "stg" ]]; then
  echo "not impled"
elif [[ $ENV_TYPE == "prd" ]]; then
  echo "not impled"
fi
