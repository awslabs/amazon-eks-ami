MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

PACKER_DEFAULT_VARIABLE_FILE ?= $(MAKEFILE_DIR)/eks-worker-al2-variables.json
PACKER_TEMPLATE_FILE ?= $(MAKEFILE_DIR)/eks-worker-al2.json
PACKER_BINARY ?= packer
AVAILABLE_PACKER_VARIABLES := $(shell $(PACKER_BINARY) inspect -machine-readable $(PACKER_TEMPLATE_FILE) | grep 'template-variable' | awk -F ',' '{print $$4}')

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

# expands to 'true' if PACKER_VARIABLE_FILE is non-empty
# and the file contains the string passed as the first argument
# otherwise, expands to 'false'
packer_variable_file_contains = $(if $(PACKER_VARIABLE_FILE),$(shell grep -Fq $1 $(PACKER_VARIABLE_FILE) && echo true || echo false),false)

# expands to 'true' if the version comparison is affirmative
# otherwise expands to 'false'
vercmp = $(shell $(MAKEFILE_DIR)/files/bin/vercmp "$1" "$2" "$3")

# Docker is not present on 1.25+ AMI's
# TODO: remove this when 1.24 reaches EOL
ifeq ($(call vercmp,$(kubernetes_version),gteq,1.25.0), true)
	# do not tag the AMI with the Docker version
	docker_version ?= none
	# do not include the Docker version in the AMI description
	ami_component_description ?= (k8s: {{ user `kubernetes_version` }}, containerd: {{ user `containerd_version` }})
endif

AMI_VERSION ?= v$(shell date '+%Y%m%d')
AMI_VARIANT ?= amazon-eks
ifneq (,$(findstring al2023, $(PACKER_TEMPLATE_FILE)))
	AMI_VARIANT := $(AMI_VARIANT)-al2023
endif
arch ?= x86_64
ifeq ($(arch), arm64)
	instance_type ?= m6g.large
	AMI_VARIANT := $(AMI_VARIANT)-arm64
else
	instance_type ?= m5.large
endif
ifeq ($(enable_fips), true)
	AMI_VARIANT := $(AMI_VARIANT)-fips
endif
ami_name ?= $(AMI_VARIANT)-node-$(K8S_VERSION_MINOR)-$(AMI_VERSION)

ifeq ($(aws_region), cn-northwest-1)
	source_ami_owners ?= 141808717104
endif

ifeq ($(aws_region), us-gov-west-1)
	source_ami_owners ?= 045324592363
endif

T_RED := \e[0;31m
T_GREEN := \e[0;32m
T_YELLOW := \e[0;33m
T_RESET := \e[0m

# default to the latest supported Kubernetes version
k8s=1.28

.PHONY: build
build: ## Build EKS Optimized AL2 AMI
	$(MAKE) k8s $(shell hack/latest-binaries.sh $(k8s))

# ensure that these flags are equivalent to the rules in the .editorconfig
SHFMT_FLAGS := --list \
--language-dialect auto \
--indent 2 \
--binary-next-line \
--case-indent \
--space-redirects

SHFMT_COMMAND := $(shell which shfmt)
ifeq (, $(SHFMT_COMMAND))
	SHFMT_COMMAND = docker run --rm -v $(MAKEFILE_DIR):$(MAKEFILE_DIR) mvdan/shfmt
endif

.PHONY: fmt
fmt: ## Format the source files
	$(SHFMT_COMMAND) $(SHFMT_FLAGS) --write $(MAKEFILE_DIR)

SHELLCHECK_COMMAND := $(shell which shellcheck)
ifeq (, $(SHELLCHECK_COMMAND))
	SHELLCHECK_COMMAND = docker run --rm -v $(MAKEFILE_DIR):$(MAKEFILE_DIR) koalaman/shellcheck:stable
endif
SHELL_FILES := $(shell find $(MAKEFILE_DIR) -type f -name '*.sh')

.PHONY: transform-al2-to-al2023
transform-al2-to-al2023:
	PACKER_TEMPLATE_FILE=$(PACKER_TEMPLATE_FILE) \
	PACKER_DEFAULT_VARIABLE_FILE=$(PACKER_DEFAULT_VARIABLE_FILE) \
		hack/transform-al2-to-al2023.sh

.PHONY: lint
lint: lint-docs ## Check the source files for syntax and format issues
	$(SHFMT_COMMAND) $(SHFMT_FLAGS) --diff $(MAKEFILE_DIR)
	$(SHELLCHECK_COMMAND) --format gcc --severity error $(SHELL_FILES)
	hack/lint-space-errors.sh

.PHONY: test
test: ## run the test-harness
	test/test-harness.sh

# include only variables which have a defined value
PACKER_VARIABLES := $(foreach packerVar,$(AVAILABLE_PACKER_VARIABLES),$(if $($(packerVar)),$(packerVar)))
PACKER_VAR_FLAGS := -var-file $(PACKER_DEFAULT_VARIABLE_FILE) \
$(if $(PACKER_VARIABLE_FILE),-var-file=$(PACKER_VARIABLE_FILE),) \
$(foreach packerVar,$(PACKER_VARIABLES),-var $(packerVar)='$($(packerVar))')

.PHONY: validate
validate: ## Validate packer config
	$(PACKER_BINARY) validate $(PACKER_VAR_FLAGS) $(PACKER_TEMPLATE_FILE)

.PHONY: k8s
k8s: validate ## Build default K8s version of EKS Optimized AL2 AMI
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build -timestamp-ui -color=false $(PACKER_VAR_FLAGS) $(PACKER_TEMPLATE_FILE)

.PHONY: 1.23
1.23: ## Build EKS Optimized AL2 AMI - K8s 1.23
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.23)

.PHONY: 1.24
1.24: ## Build EKS Optimized AL2 AMI - K8s 1.24
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.24)

.PHONY: 1.25
1.25: ## Build EKS Optimized AL2 AMI - K8s 1.25
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.25)

.PHONY: 1.26
1.26: ## Build EKS Optimized AL2 AMI - K8s 1.26
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.26)

.PHONY: 1.27
1.27: ## Build EKS Optimized AL2 AMI - K8s 1.27
	$(MAKE) k8s $(shell hack/latest-binaries.sh 1.27)

.PHONY: 1.28
1.28: ## Build EKS Optimized AL2 AMI - K8s 1.28
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
