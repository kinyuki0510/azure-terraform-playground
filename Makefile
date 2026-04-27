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

#guard-%:
#	@[ -n "${$*}" ] || (echo "ERROR: $* is required"; exit 1)

.PHONY: tf_init tf_plan tf_apply tf_destroy tf_destroy_target

tf_init: guard-env
	terraform -chdir=$(TERRAFORM_DIR) init -backend-config="environments/$(env).backend.hcl" -reconfigure

tf_plan: guard-env guard-ip guard-upn
	terraform -chdir=$(TERRAFORM_DIR) plan -var-file="environments/$(env).tfvars" -var='allowed_ips=["$(MY_IP)"]' -var='deployer_upn=$(DEPLOYER_UPN)' -out=$(env).tfplan

tf_show: guard-env
	terraform -chdir=$(TERRAFORM_DIR) show $(env).tfplan

tf_apply: guard-env guard-ip guard-upn
	terraform -chdir=$(TERRAFORM_DIR) apply -var-file="environments/$(env).tfvars" -var='allowed_ips=["$(MY_IP)"]' -var='deployer_upn=$(DEPLOYER_UPN)'

#tf_destroy: guard-env
#	terraform -chdir=$(TERRAFORM_DIR) destroy -var-file="environments/$(env).tfvars"

tf_destroy_target: guard-env guard-target
	terraform -chdir=$(TERRAFORM_DIR) destroy -var-file="environments/$(env).tfvars" -target=$(target)