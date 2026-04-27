#!/bin/bash
# init-storage-env.sh
# 使い方: source ./init-storage-env.sh -s <STORAGE_ACCOUNT> -r <RESOURCE_GROUP>

usage() {
  [ -n "$1" ] && echo "エラー: $1" >&2
  cat >&2 <<EOF

使い方:
  source ./init-storage-env.sh -s <STORAGE_ACCOUNT> -r <RESOURCE_GROUP>

オプション:
  -s, --storage-account    Storage Account名（必須）
  -r, --resource-group     Resource Group名（必須）
  -h, --help               このヘルプを表示

例:
  source ./init-storage-env.sh -s myapp001 -r myapp-rg
  source ./init-storage-env.sh --storage-account myapp001 --resource-group myapp-rg
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --storage-account|-s)
      if [ -z "$2" ]; then
        usage "-s には値が必要です"
        return 1
      fi
      STORAGE_ACCOUNT="$2"
      shift 2
      ;;
    --resource-group|-r)
      if [ -z "$2" ]; then
        usage "-r には値が必要です"
        return 1
      fi
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --help|-h)
      usage
      return 0
      ;;
    *)
      usage "不明なオプション: $1"
      return 1
      ;;
  esac
done

if [ -z "$STORAGE_ACCOUNT" ] || [ -z "$RESOURCE_GROUP" ]; then
  usage "-s と -r は必須です"
  return 1
fi

if [ -n "$AZURE_STORAGE_CONNECTION_STRING" ]; then
  echo "⚠️  既存の AZURE_STORAGE_CONNECTION_STRING を上書きします" >&2
fi

export AZURE_STORAGE_CONNECTION_STRING=$(
  az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --output tsv
)

echo "✅ AZURE_STORAGE_CONNECTION_STRING をセットしました"
echo "   Storage Account : $STORAGE_ACCOUNT"
echo "   Resource Group  : $RESOURCE_GROUP"

