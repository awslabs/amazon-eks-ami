MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# `kubernetes_version` is a build variable, but requires some introspection
# to dynamically determine build templates & variable defaults.
# initialize the kubernetes version from the provided packer file if missing.
ifeq ($(kubernetes_version),)
ifneq ($(PACKER_VARIABLE_FILE),)
	kubernetes_version ?= $(shell jq -r .kubernetes_version $(PACKER_VARIABLE_FILE))
endif
endif

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

AMI_VARIANT ?= amazon-eks
AMI_VERSION ?= v$(shell date '+%Y%m%d')
aws_region ?= us-west-2
arch ?= x86_64

BUILD_TARGETS := build k8s validate

ifneq ($(filter $(BUILD_TARGETS),$(MAKECMDGOALS)),)
ifndef os_distro
$(error os_distro is required (e.g., os_distro=al2023))
endif
ifndef k8s
$(error k8s is required (e.g., k8s=1.35))
endif
endif

ifeq ($(os_distro), al2023)
	AMI_VARIANT := $(AMI_VARIANT)-al2023
endif
ifeq ($(arch), arm64)
	instance_type ?= m6g.large
	AMI_VARIANT := $(AMI_VARIANT)-arm64
else
	instance_type ?= m5.large
endif
ifeq ($(enable_fips), true)
	AMI_VARIANT := $(AMI_VARIANT)-fips
endif

ifdef enable_accelerator
	AMI_VARIANT := $(AMI_VARIANT)-$(enable_accelerator)
endif

ami_name ?= $(AMI_VARIANT)-node-$(K8S_VERSION_MINOR)-$(AMI_VERSION)

ifeq ($(aws_region), cn-northwest-1)
	source_ami_owners ?= 141808717104
else ifneq ($(filter $(aws_region),us-gov-west-1 us-gov-east-1),)
	source_ami_owners ?= 045324592363
endif

.PHONY: build
build: ## Build EKS Optimized AMI (requires os_distro=al2023)
	$(MAKE) k8s $(shell hack/latest-binaries.sh $(k8s) $(aws_region))

.PHONY: fmt
fmt: ## Format the source files
	hack/shfmt --write

.PHONY: lint
lint: lint-docs lint-code
  # Convenience target to run all lints. This is not run during presubmits, add new checks in lint-docs or lint-code.

.PHONY: lint-code
lint-code: ## Check the source files for syntax and format issues
	hack/shfmt --diff
	hack/shellcheck --format gcc --severity warning
	hack/lint-space-errors.sh

PACKER_BINARY ?= packer
PACKER_TEMPLATE_DIR ?= templates/$(os_distro)
PACKER_TEMPLATE_FILE ?= $(PACKER_TEMPLATE_DIR)/template.json
PACKER_DEFAULT_VARIABLE_FILE ?= $(PACKER_TEMPLATE_DIR)/variables-default.json
PACKER_OPTIONAL_K8S_VARIABLE_FILE ?= $(PACKER_TEMPLATE_DIR)/variables-$(K8S_VERSION_MINOR).json
ifeq (,$(wildcard $(PACKER_OPTIONAL_K8S_VARIABLE_FILE)))
	# unset the variable, no k8s-specific variable file exists
	PACKER_OPTIONAL_K8S_VARIABLE_FILE=
endif

# extract Packer variables from the template file,
# then store variables that are defined in the Makefile's execution context
AVAILABLE_PACKER_VARIABLES := $(shell $(PACKER_BINARY) inspect -machine-readable $(PACKER_TEMPLATE_FILE) | grep 'template-variable' | awk -F ',' '{print $$4}')
PACKER_VARIABLES := $(foreach packerVar,$(AVAILABLE_PACKER_VARIABLES),$(if $($(packerVar)),$(packerVar)))
# read & construct Packer arguments in order from the following sources:
# 1. default variable files
# 2. (optional) user-specified variable file
# 3. variables specified in the Make context
PACKER_ARGS := -var-file $(PACKER_DEFAULT_VARIABLE_FILE) \
	$(if $(PACKER_OPTIONAL_K8S_VARIABLE_FILE),-var-file=$(PACKER_OPTIONAL_K8S_VARIABLE_FILE),) \
	$(if $(PACKER_VARIABLE_FILE),-var-file=$(PACKER_VARIABLE_FILE),) \
	$(foreach packerVar,$(PACKER_VARIABLES),-var $(packerVar)='$($(packerVar))')

.PHONY: validate
validate: ## Validate packer config
	@echo "PACKER_TEMPLATE_FILE: $(PACKER_TEMPLATE_FILE)"
	@echo "PACKER_ARGS: $(PACKER_ARGS)"
	$(PACKER_BINARY) validate $(PACKER_ARGS) $(PACKER_TEMPLATE_FILE)

.PHONY: k8s
k8s: validate ## Build default K8s version of EKS Optimized AMI
	@echo "Building AMI [os_distro=$(os_distro) kubernetes_version=$(kubernetes_version) arch=$(arch) $(if $(enable_accelerator),enable_accelerator=$(enable_accelerator))]"
	$(PACKER_BINARY) build -timestamp-ui -color=false $(PACKER_ARGS) $(PACKER_TEMPLATE_FILE)

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
