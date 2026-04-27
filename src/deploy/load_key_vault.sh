#!/bin/bash

set -euo pipefail

TEMP_DIR=".temp_dir"
mkdir -p "$TEMP_DIR"
#trap 'find "$TEMP_DIR" -type f -delete' EXIT

# Key Vaultの全シークレットをJSONに読み込み、ファイルパスを返却する
# AWS SSMの get-parameters-by-path に相当
# 注意: シークレット数が多い場合はAPI呼び出し回数が増える（1件1回）
function load_kv_secrets() {
  local _vault_name="$1"
  local _temp_file
  _temp_file=$(mktemp -p "${TEMP_DIR}" kv-secrets-XXXXXX.json)

  local _names
  _names=$(az keyvault secret list --vault-name "$_vault_name" --query "[].name" -o tsv)

  # Key Vaultは一括値取得APIが存在しないため並列fetchで待ち時間を削減する
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

# シークレットファイルから指定した名前の値を環境変数にセットする
# AWS SSMの set_environment_variables_from_ssm に相当
function set_environment_variables_from_kv() {
  local _kv_secret_file="$1"
  local _secret_name="$2"
  local _environment_variable_name="$3"

  local _val
  _val=$(jq -r '.secrets[] | select(.Name == $secret_name) | .Value' \
    --arg secret_name "$_secret_name" < "$_kv_secret_file")

  export "${_environment_variable_name}=${_val}"
}

# --- 使用例（vault名は実際の値に変更すること） ---
VAULT_NAME="${KV_VAULT_NAME:?KV_VAULT_NAME が未設定です}"

load_kv_secrets "$VAULT_NAME" JSON_PATH

set_environment_variables_from_kv "$JSON_PATH" "pg-admin-password"       "PG_ADMIN_PASSWORD"
set_environment_variables_from_kv "$JSON_PATH" "blob-connection-string"   "BLOB_CONNECTION_STRING"
