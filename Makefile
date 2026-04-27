TERRAFORM_DIR = src/infra
MY_IP         := $(shell curl -s --max-time 5 ifconfig.me 2>/dev/null)
DEPLOYER_UPN  := $(shell az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null)

guard-env:
	@[ -n "$(env)" ] || (echo "ERROR: env is required. usage: make <target> env=<dev|stg|prd>"; exit 1)

guard-target:
	@[ -n "$(target)" ] || (echo "ERROR: target is required. usage: make tf_destroy_target env=<dev|stg|prd> target=<resource>"; exit 1)

guard-ip:
	@[ -n "$(MY_IP)" ] || (echo "ERROR: Failed to fetch global IP. Check network connection."; exit 1)

guard-upn:
	@[ -n "$(DEPLOYER_UPN)" ] || (echo "ERROR: Failed to fetch UPN. Run: az login"; exit 1)

.PHONY: tf_init tf_plan tf_show tf_apply tf_destroy_target

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

tf_destroy_target: guard-env guard-target
	TF_VAR_appconfig_name=atp-$(env)-appconfig \
	TF_VAR_bootstrap_rg=atp-keyvault-$(env)-rg \
	terraform -chdir=$(TERRAFORM_DIR) destroy \
	  -var='allowed_ips=["$(MY_IP)"]' \
	  -var='deployer_upn=$(DEPLOYER_UPN)' \
	  -target=$(target)

SOURCE_DIR = src/app
py_init:
	if [ ! -f $(SOURCE_DIR)/pyproject.toml ]; then uv init --directory=$(SOURCE_DIR); fi
	uv add --directory=$(SOURCE_DIR) alembic sqlalchemy psycopg2-binary python-jose passlib pydantic-settings anthropic
	@if [ ! -d $(SOURCE_DIR)/migration ]; then uv run --directory=$(SOURCE_DIR) alembic init migration; fi