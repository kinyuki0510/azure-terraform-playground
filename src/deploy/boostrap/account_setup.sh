#!/bin/bash

usage() {
  echo "Usage: $0 --env <dev|stg|prd>" >&2
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
    *)
      usage
      ;;
  esac
done

if [[ -z $ENV_TYPE ]]; then usage; fi

ACTUAL_SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
ACTUAL_SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)

echo "Deploying to env : ${ENV_TYPE}"
echo "Subscription     : ${ACTUAL_SUBSCRIPTION_NAME} (${ACTUAL_SUBSCRIPTION_ID})"
read -rp "Continue? [y/N] " _confirm
[[ "${_confirm}" =~ ^[Yy]$ ]] || exit 1

function register_providers() {
  local _providers=(
    "Microsoft.AppConfiguration"
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

function create_app_configuration() {
  local _name="${1}"
  local _resource_group="${2}"

  az appconfig create \
    --name "${_name}" \
    --resource-group "${_resource_group}" \
    --location "japaneast" \
    --sku Free
}

function set_appconfig_value() {
  local _name="${1}"
  local _key="${2}"
  local _value="${3}"

  az appconfig kv set \
    --name "${_name}" \
    --key "${_key}" \
    --value "${_value}" \
    --yes
}

if [[ $ENV_TYPE == "dev" ]]; then
  KV_NAME="atp-dev-kv"
  APPCONFIG_NAME="atp-dev-appconfig"
  RG_NAME="atp-keyvault-dev-rg"

  register_providers
  create_keyvault "${KV_NAME}" "${RG_NAME}"
  create_app_configuration "${APPCONFIG_NAME}" "${RG_NAME}"

  #set_keyvault_secret "${KV_NAME}" "account-envtype" "dev"

  # Store subscription ID in App Configuration for post-bootstrap scripts to validate
  set_appconfig_value "${APPCONFIG_NAME}" "/account/envtype" "dev"
  set_appconfig_value "${APPCONFIG_NAME}" "/account/subscription-id" "${ACTUAL_SUBSCRIPTION_ID}"
  set_appconfig_value "${APPCONFIG_NAME}" "/account/subscription-name" "${ACTUAL_SUBSCRIPTION_NAME}"
  set_appconfig_value "${APPCONFIG_NAME}" "/resource/location"     "japaneast"
  set_appconfig_value "${APPCONFIG_NAME}" "/resource/prefix"       "atp-${ENV_TYPE}"
  set_appconfig_value "${APPCONFIG_NAME}" "/resource/boostrap-rg"  "${RG_NAME}"
  set_appconfig_value "${APPCONFIG_NAME}" "/resource/ghcr-image-url" "ghcr.io/kinyuki/azure-terraform-playground"
  set_appconfig_value "${APPCONFIG_NAME}" "/resource/image-tag"      "latest"

elif [[ $ENV_TYPE == "stg" ]]; then
  echo "not impled"
elif [[ $ENV_TYPE == "prd" ]]; then
  echo "not impled"
fi
