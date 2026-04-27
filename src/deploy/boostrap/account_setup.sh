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
  local _label="${4:-}"

  local _label_args=()
  if [[ -n "$_label" ]]; then
    _label_args=(--label "$_label")
  fi

  az appconfig kv set \
    --name "${_name}" \
    --key "${_key}" \
    --value "${_value}" \
    "${_label_args[@]}" \
    --yes
}

function set_appconfig_keyvault_ref() {
  local _name="${1}"
  local _key="${2}"
  local _secret_identifier="${3}"
  local _label="${4:-}"

  local _label_args=()
  if [[ -n "$_label" ]]; then
    _label_args=(--label "$_label")
  fi

  az appconfig kv set-keyvault \
    --name "${_name}" \
    --key "${_key}" \
    --secret-identifier "${_secret_identifier}" \
    "${_label_args[@]}" \
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

  # JWT secret → Key Vault（local/azure共通）
  JWT_SECRET=$(openssl rand -base64 32)
  set_keyvault_secret "${KV_NAME}" "jwt-secret" "${JWT_SECRET}"
  unset JWT_SECRET
  KV_JWT_SECRET_URI="https://${KV_NAME}.vault.azure.net/secrets/jwt-secret"

  # Backend parameters - local label
  PG_SUFFIX="${ACTUAL_SUBSCRIPTION_ID:0:8}"
  set_appconfig_value "${APPCONFIG_NAME}"         "/backend/database/url"        "postgresql://pgadmin:localdev@localhost:5432/appdb" "local"
  set_appconfig_keyvault_ref "${APPCONFIG_NAME}"  "/backend/auth/jwt-secret"     "${KV_JWT_SECRET_URI}"                               "local"
  set_appconfig_value "${APPCONFIG_NAME}"         "/backend/auth/expire-minutes" "60"                                                 "local"

  # Backend parameters - azure label
  PG_HOST="atp-${ENV_TYPE}-pg-${PG_SUFFIX}.postgres.database.azure.com"
  set_appconfig_value "${APPCONFIG_NAME}"         "/backend/database/url"        "postgresql://pgadmin@${PG_HOST}:5432/appdb?sslmode=require" "azure"
  set_appconfig_keyvault_ref "${APPCONFIG_NAME}"  "/backend/auth/jwt-secret"     "${KV_JWT_SECRET_URI}"                                      "azure"
  set_appconfig_value "${APPCONFIG_NAME}"         "/backend/auth/expire-minutes" "60"                                                        "azure"

elif [[ $ENV_TYPE == "stg" ]]; then
  echo "not impled"
elif [[ $ENV_TYPE == "prd" ]]; then
  echo "not impled"
fi
