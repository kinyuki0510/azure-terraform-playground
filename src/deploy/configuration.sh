#!/bin/bash

set -euo pipefail

TEMP_DIR=".temp_dir"
mkdir -p "$TEMP_DIR"
trap 'find "$TEMP_DIR" -type f -delete' EXIT

# ---------------------------------------------------------------------------
# App Configuration
# ---------------------------------------------------------------------------

# Fetch all key-values from App Configuration in a single API call.
# AWS SSM get-parameters-by-path equivalent.
# Usage: load_appconfig_values "$APPCONFIG_NAME" JSON_PATH
function load_appconfig_values() {
  local _name="$1"
  local _temp_file
  _temp_file=$(mktemp -p "${TEMP_DIR}" appconfig-XXXXXX.json)

  az appconfig kv list \
    --name "$_name" \
    --query "[].{Key:key,Value:value}" \
    -o json > "$_temp_file"

  eval "$2=\"$_temp_file\""
}

# Read a value from the App Configuration JSON and export as environment variable.
# Usage: set_env_from_appconfig "$JSON_PATH" "/account/subscription-id" SUBSCRIPTION_ID
function set_env_from_appconfig() {
  local _file="$1"
  local _key="$2"
  local _env_var="$3"

  local _val
  _val=$(jq -r --arg key "$_key" '.[] | select(.Key == $key) | .Value' < "$_file")

  if [[ -z "${_val}" || "${_val}" == "null" ]]; then
    echo "ERROR: key '${_key}' not found in App Configuration" >&2
    return 1
  fi

  export "${_env_var}=${_val}"
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------

# Fetch all secrets from Key Vault in parallel (Key Vault has no batch-value API).
# Usage: load_kv_secrets "$VAULT_NAME" JSON_PATH
function load_kv_secrets() {
  local _vault_name="$1"
  local _temp_file
  _temp_file=$(mktemp -p "${TEMP_DIR}" kv-secrets-XXXXXX.json)

  local _names
  _names=$(az keyvault secret list --vault-name "$_vault_name" --query "[].name" -o tsv)

  declare -A _pid_map
  declare -A _file_map

  while IFS= read -r _name; do
    local _val_file
    _val_file=$(mktemp -p "${TEMP_DIR}" kv-val-XXXXXX.json)
    _file_map[$_name]="$_val_file"
    az keyvault secret show --vault-name "$_vault_name" --name "$_name" \
      --query "{Name:name,Value:value}" -o json > "$_val_file" &
    _pid_map[$_name]=$!
  done <<< "$_names"

  local _json='{"secrets": []}'
  for _name in "${!_pid_map[@]}"; do
    wait "${_pid_map[$_name]}"
    _json=$(jq --slurpfile entry "${_file_map[$_name]}" '.secrets += $entry' <<< "$_json")
  done

  echo "$_json" > "$_temp_file"
  eval "$2=\"$_temp_file\""
}

# Read a secret from the Key Vault JSON and export as environment variable.
# Usage: set_env_from_kv "$JSON_PATH" "blob-connection-string" BLOB_CONNECTION_STRING
function set_env_from_kv() {
  local _file="$1"
  local _secret_name="$2"
  local _env_var="$3"

  local _val
  _val=$(jq -r --arg name "$_secret_name" \
    '.secrets[] | select(.Name == $name) | .Value' < "$_file")

  if [[ -z "${_val}" || "${_val}" == "null" ]]; then
    echo "ERROR: secret '${_secret_name}' not found in Key Vault" >&2
    return 1
  fi

  export "${_env_var}=${_val}"
}

# ---------------------------------------------------------------------------
# Usage example
# ---------------------------------------------------------------------------
# APPCONFIG_NAME="${APPCONFIG_NAME:?APPCONFIG_NAME is not set}"
# VAULT_NAME="${KV_VAULT_NAME:?KV_VAULT_NAME is not set}"

CURRENT_SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

load_appconfig_values "$APPCONFIG_NAME" APPCONFIG_JSON
set_env_from_appconfig "$APPCONFIG_JSON" "/account/envtype"          ENV_TYPE
set_env_from_appconfig "$APPCONFIG_JSON" "/account/subscription-id" SUBSCRIPTION_ID
set_env_from_appconfig "$APPCONFIG_JSON" "/account/subscription-name" SUBSCRIPTION_NAME

if [[ "${CURRENT_SUBSCRIPTION_ID}" != "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR: subscription mismatch" >&2
  echo "  current: ${CURRENT_SUBSCRIPTION_ID}" >&2
  echo "  target : ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})" >&2
  exit 1
fi

#
# load_kv_secrets "$VAULT_NAME" KV_JSON
# set_env_from_kv "$KV_JSON" "blob-connection-string" BLOB_CONNECTION_STRING
