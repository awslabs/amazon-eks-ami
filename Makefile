MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# `kubernetes_version` is a build variable, but requires some introspection
# to dynamically pull determine build templates & variable defaults.
# initialize the kubernetes version from the provided variables if missing.
ifeq ($(kubernetes_version),)
ifneq ($(PACKER_VARIABLE_FILE),)
	kubernetes_version ?= $(shell jq -r .kubernetes_version $(PACKER_VARIABLE_FILE))
endif
endif

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

AMI_VARIANT ?= amazon-eks
AMI_VERSION ?= v$(shell date '+%Y%m%d')
al_variant ?= al2
arch ?= x86_64
instance_type ?= m5.large

ifeq ($(al_variant), al2023)
	AMI_VARIANT := $(AMI_VARIANT)-al2023
endif
ifeq ($(arch), arm64)
	instance_type ?= m6g.large
	AMI_VARIANT := $(AMI_VARIANT)-arm64
endif
ifeq ($(enable_fips), true)
	AMI_VARIANT := $(AMI_VARIANT)-fips
endif

ami_name ?= $(AMI_VARIANT)-node-$(K8S_VERSION_MINOR)-$(AMI_VERSION)

# ami owner overrides for cn/gov-cloud
ifeq ($(aws_region), cn-northwest-1)
	source_ami_owners ?= 141808717104
else ifeq ($(aws_region), us-gov-west-1)
	source_ami_owners ?= 045324592363
endif

# default to the latest supported Kubernetes version
k8s=1.28

.PHONY: build
build: ## Build EKS Optimized AMI, default using AL2, use al_variant=al2023 for AL2023 AMI
	$(MAKE) k8s $(shell hack/latest-binaries.sh $(k8s))

# ensure that these flags are equivalent to the rules in the .editorconfig
SHFMT_FLAGS := --list \
--language-dialect auto \
--indent 2 \
--binary-next-line \
--case-indent \
--space-redirects

.PHONY: fmt
fmt: ## Format the source files
	hack/shfmt $(SHFMT_FLAGS) --write $(MAKEFILE_DIR)

.PHONY: lint
lint: lint-docs ## Check the source files for syntax and format issues
	hack/shfmt $(SHFMT_FLAGS) --diff $(MAKEFILE_DIR)
	hack/shellcheck --format gcc --severity error $(shell find $(MAKEFILE_DIR) -type f -name '*.sh')
	hack/lint-space-errors.sh

.PHONY: test
test: ## run the test-harness
	test/test-harness.sh

PACKER_BINARY ?= packer
PACKER_TEMPLATE_DIR ?= templates/$(al_variant)/$(K8S_VERSION_MINOR)
PACKER_TEMPLATE_FILE ?= $(PACKER_TEMPLATE_DIR)/template.json
PACKER_DEFAULT_VARIABLE_FILE ?= $(PACKER_TEMPLATE_DIR)/variables.json
# extract Packer variables from the template file,
# then store variables that are defined in the Makefile's execution context
AVAILABLE_PACKER_VARIABLES := $(shell $(PACKER_BINARY) inspect -machine-readable $(PACKER_TEMPLATE_FILE) | grep 'template-variable' | awk -F ',' '{print $$4}')
PACKER_VARIABLES := $(foreach packerVar,$(AVAILABLE_PACKER_VARIABLES),$(if $($(packerVar)),$(packerVar)))
# read & construct Packer arguments in order from the following sources:
# 1. default variable files
# 2. (optional) user-specified variable file
# 3. variables specified in the Make context
PACKER_ARGS := -var-file $(PACKER_DEFAULT_VARIABLE_FILE) \
	$(if $(PACKER_VARIABLE_FILE),-var-file=$(PACKER_VARIABLE_FILE),) \
	$(foreach packerVar,$(PACKER_VARIABLES),-var $(packerVar)='$($(packerVar))')

.PHONY: validate
validate: ## Validate packer config
	@echo "PACKER_TEMPLATE_FILE: $(PACKER_TEMPLATE_FILE)"
	@echo "PACKER_ARGS: $(PACKER_ARGS)"
	$(PACKER_BINARY) validate $(PACKER_ARGS) $(PACKER_TEMPLATE_FILE)

.PHONY: k8s
k8s: validate ## Build default K8s version of EKS Optimized AMI
	@echo "Building AMI [al_variant=$(al_variant) kubernetes_version=$(kubernetes_version) arch=$(arch)]"
	$(PACKER_BINARY) build -timestamp-ui -color=false $(PACKER_ARGS) $(PACKER_TEMPLATE_FILE)

.PHONY: 1.23
1.23: ## Build EKS Optimized AMI - K8s 1.23
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.23)

.PHONY: 1.24
1.24: ## Build EKS Optimized AMI - K8s 1.24
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.24)

.PHONY: 1.25
1.25: ## Build EKS Optimized AMI - K8s 1.25
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.25)

.PHONY: 1.26
1.26: ## Build EKS Optimized AMI - K8s 1.26
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.26)

.PHONY: 1.27
1.27: ## Build EKS Optimized AMI - K8s 1.27
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.27)

.PHONY: 1.28
1.28: ## Build EKS Optimized AMI - K8s 1.28
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.28)

.PHONY: lint-docs
lint-docs: ## Lint the docs
	hack/lint-docs.sh

.PHONY: clean
clean:
	rm *-manifest.json
	rm *-version-info.json

.PHONY: help
help: ## Display help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[\.a-zA-Z_0-9\-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
