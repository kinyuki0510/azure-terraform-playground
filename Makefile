SHELL      := /bin/bash
TERRAFORM_DIR = src/infra
SOURCE_DIR    = src/app
MY_IP         := $(shell curl -s --max-time 5 ifconfig.me 2>/dev/null)
DEPLOYER_UPN  := $(shell az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null)

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------

guard-env:
	@[ -n "$(env)" ] || (echo "ERROR: env is required. usage: make <target> env=<dev|stg|prd>"; exit 1)

guard-target:
	@[ -n "$(target)" ] || (echo "ERROR: target is required. usage: make tf_destroy_target env=<dev|stg|prd> target=<resource>"; exit 1)

guard-ip:
	@[ -n "$(MY_IP)" ] || (echo "ERROR: Failed to fetch global IP. Check network connection."; exit 1)

guard-upn:
	@[ -n "$(DEPLOYER_UPN)" ] || (echo "ERROR: Failed to fetch UPN. Run: az login"; exit 1)

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

.PHONY: tf_init tf_plan tf_show tf_apply tf_destroy tf_destroy_target

tf_init: guard-env
	terraform -chdir=$(TERRAFORM_DIR) init -backend-config="environments/$(env).backend.hcl" -reconfigure

tf_plan: guard-env guard-ip guard-upn
	TF_VAR_appconfig_name=atp-$(env)-appconfig \
	TF_VAR_bootstrap_rg=atp-keyvault-$(env)-rg \
	terraform -chdir=$(TERRAFORM_DIR) plan \
	  -var='allowed_ips=["$(MY_IP)"]' \
	  -var='deployer_upn=$(DEPLOYER_UPN)' \
	  -out=$(env).tfplan

tf_show: guard-env
	terraform -chdir=$(TERRAFORM_DIR) show $(env).tfplan

tf_apply: guard-env guard-ip guard-upn
	TF_VAR_appconfig_name=atp-$(env)-appconfig \
	TF_VAR_bootstrap_rg=atp-keyvault-$(env)-rg \
	terraform -chdir=$(TERRAFORM_DIR) apply \
	  -var='allowed_ips=["$(MY_IP)"]' \
	  -var='deployer_upn=$(DEPLOYER_UPN)'

tf_destroy: guard-env guard-ip guard-upn
	TF_VAR_appconfig_name=atp-$(env)-appconfig \
	TF_VAR_bootstrap_rg=atp-keyvault-$(env)-rg \
	terraform -chdir=$(TERRAFORM_DIR) destroy \
	  -var='allowed_ips=["$(MY_IP)"]' \
	  -var='deployer_upn=$(DEPLOYER_UPN)'

tf_destroy_target: guard-env guard-target
	TF_VAR_appconfig_name=atp-$(env)-appconfig \
	TF_VAR_bootstrap_rg=atp-keyvault-$(env)-rg \
	terraform -chdir=$(TERRAFORM_DIR) destroy \
	  -var='allowed_ips=["$(MY_IP)"]' \
	  -var='deployer_upn=$(DEPLOYER_UPN)' \
	  -target=$(target)

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------

.PHONY: fetch_config py_init run test_init test_run lint format typecheck check

fetch_config:
	@[ -n "$(env)" ] || { echo "Usage: make fetch_config env=dev context=local"; exit 1; }
	@[ -n "$(context)" ] || { echo "Usage: make fetch_config env=dev context=local"; exit 1; }
	bash src/deploy/fetch_config.sh --env $(env) --context $(context)
	direnv allow

py_init:
	@if [ ! -f $(SOURCE_DIR)/pyproject.toml ]; then uv init --directory=$(SOURCE_DIR); fi
	uv add --directory=$(SOURCE_DIR) fastapi uvicorn alembic sqlalchemy psycopg2-binary python-jose passlib pydantic-settings anthropic structlog
	@if [ ! -d $(SOURCE_DIR)/migration ]; then uv run --directory=$(SOURCE_DIR) alembic init migration; fi

py_run:
	uv run --directory=$(SOURCE_DIR) uvicorn main:app --reload

#py_test_init:
#	uv add --directory=$(SOURCE_DIR) --group test pytest pytest-asyncio httpx

#py_test_run:
#	cd $(SOURCE_DIR) && uv run pytest ../../tests; code=$$?; [ $$code -eq 5 ] && exit 0 || exit $$code

py_lint:
	uv run --directory=$(SOURCE_DIR) --with ruff ruff check . $(if $(fix),--fix,)

py_format:
	#uv run --directory=$(SOURCE_DIR) --with ruff ruff format . $(if $(file),$(file),$(SOURCE_DIR))
	uv run --directory=$(SOURCE_DIR) --with ruff ruff format . 

py_typecheck:
	uv run --directory=$(SOURCE_DIR) --with mypy mypy $(SOURCE_DIR) --explicit-package-bases --ignore-missing-imports

check: lint format typecheck

# ---------------------------------------------------------------------------
# DB
# ---------------------------------------------------------------------------

.PHONY: db_migrate db_revision db_upgrade db_stamp db_backup db_restore

db_migrate:
	@[ -n "$(msg)" ] || { echo "Usage: make db_migrate msg=\"your message\""; exit 1; }
	uv run --directory=$(SOURCE_DIR) alembic revision --autogenerate -m "$(msg)"
	uv run --directory=$(SOURCE_DIR) alembic upgrade head

db_revision:
	@[ -n "$(msg)" ] || { echo "Usage: make db_revision msg=\"your message\""; exit 1; }
	uv run --directory=$(SOURCE_DIR) alembic revision -m "$(msg)"

db_upgrade:
	uv run --directory=$(SOURCE_DIR) alembic upgrade head

db_stamp:
	@[ -n "$(rev)" ] || { echo "Usage: make db_stamp rev=<revision>"; exit 1; }
	uv run --directory=$(SOURCE_DIR) alembic stamp $(rev)

db_backup:
	docker compose exec db pg_dump --clean --if-exists -U $$POSTGRES_USER $$POSTGRES_DB > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup saved."

db_restore:
	@[ -n "$(file)" ] || { echo "Usage: make db_restore file=backup_xxx.sql"; exit 1; }
	docker compose exec -T db psql -U $$POSTGRES_USER $$POSTGRES_DB < $(file)
