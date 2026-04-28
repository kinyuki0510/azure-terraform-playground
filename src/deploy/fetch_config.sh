#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 --env <dev|stg|prd> --context <local|azure>" >&2
  exit 1
}

while [[ "${#}" -gt 0 ]]; do
  case "${1}" in
    --env)
      ENV_TYPE="${2}"
      if [[ ! "${ENV_TYPE}" =~ ^(dev|stg|prd)$ ]]; then usage; fi
      shift 2
      ;;
    --context)
      CONTEXT="${2}"
      if [[ ! "${CONTEXT}" =~ ^(local|azure)$ ]]; then usage; fi
      shift 2
      ;;
    *) usage ;;
  esac
done

if [[ -z "${ENV_TYPE:-}" ]] || [[ -z "${CONTEXT:-}" ]]; then usage; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVRC_FILE="${SCRIPT_DIR}/../../.envrc"
APPCONFIG_NAME="atp-${ENV_TYPE}-appconfig"

# Load App Configuration and validate subscription
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/configuration.sh"

# Load values for the specified context label
load_appconfig_values "${APPCONFIG_NAME}" CONTEXT_JSON "${CONTEXT}"

# Generate .envrc
> "${ENVRC_FILE}"

write_envrc_from_appconfig "${CONTEXT_JSON}" "/backend/database/url"        DATABASE_URL       "${ENVRC_FILE}"
write_envrc_from_appconfig "${CONTEXT_JSON}" "/backend/auth/jwt-secret"     JWT_SECRET         "${ENVRC_FILE}"
write_envrc_from_appconfig "${CONTEXT_JSON}" "/backend/auth/expire-minutes" JWT_EXPIRE_MINUTES "${ENVRC_FILE}"

echo "Generated ${ENVRC_FILE} for env=${ENV_TYPE} context=${CONTEXT}"
