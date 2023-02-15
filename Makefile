PACKER_BINARY ?= packer
AVAILABLE_PACKER_VARIABLES := $(shell $(PACKER_BINARY) inspect -machine-readable eks-worker-al2.json | grep 'template-variable' | awk -F ',' '{print $$4}')

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# Docker is not present on 1.25+ AMI's
ifeq ($(shell $(MAKEFILE_DIR)/files/bin/vercmp "$(kubernetes_version)" gteq "1.25.0"), true)
# do not tag the AMI with the Docker version
docker_version ?= none
# do not include the Docker version in the AMI description
ami_component_description ?= (k8s: {{ user `kubernetes_version` }}, containerd: {{ user `containerd_version` }})
endif

arch ?= x86_64
ifeq ($(arch), arm64)
instance_type ?= m6g.large
ami_name ?= amazon-eks-arm64-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d')
else
instance_type ?= m4.large
ami_name ?= amazon-eks-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d')
endif

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

.PHONY: all
all: 1.21 1.22 1.23 1.24 1.25 ## Build all versions of EKS Optimized AL2 AMI

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

.PHONY: lint
lint: ## Check the source files for syntax and format issues
	$(SHFMT_COMMAND) $(SHFMT_FLAGS) --diff $(MAKEFILE_DIR)
	$(SHELLCHECK_COMMAND) --format gcc --severity error $(SHELL_FILES)

.PHONY: test
test: ## run the test-harness
	test/test-harness.sh

# include only variables which have a defined value
PACKER_VARIABLES := $(foreach packerVar,$(AVAILABLE_PACKER_VARIABLES),$(if $($(packerVar)),$(packerVar)))
PACKER_VAR_FLAGS := -var-file eks-worker-al2-variables.json \
$(if $(PACKER_VARIABLE_FILE),--var-file=$(PACKER_VARIABLE_FILE),) \
$(foreach packerVar,$(PACKER_VARIABLES),-var $(packerVar)='$($(packerVar))')

.PHONY: validate
validate: ## Validate packer config
	$(PACKER_BINARY) validate $(PACKER_VAR_FLAGS) eks-worker-al2.json

.PHONY: k8s
k8s: validate ## Build default K8s version of EKS Optimized AL2 AMI
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build -timestamp-ui -color=false $(PACKER_VAR_FLAGS) eks-worker-al2.json

# Build dates and versions taken from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

.PHONY: 1.21
1.21: ## Build EKS Optimized AL2 AMI - K8s 1.21
	$(MAKE) k8s kubernetes_version=1.21.14 kubernetes_build_date=2023-01-30 pull_cni_from_github=true

.PHONY: 1.22
1.22: ## Build EKS Optimized AL2 AMI - K8s 1.22
	$(MAKE) k8s kubernetes_version=1.22.17 kubernetes_build_date=2023-01-30 pull_cni_from_github=true

.PHONY: 1.23
1.23: ## Build EKS Optimized AL2 AMI - K8s 1.23
	$(MAKE) k8s kubernetes_version=1.23.16 kubernetes_build_date=2023-01-30 pull_cni_from_github=true

.PHONY: 1.24
1.24: ## Build EKS Optimized AL2 AMI - K8s 1.24
	$(MAKE) k8s kubernetes_version=1.24.10 kubernetes_build_date=2023-01-30 pull_cni_from_github=true

.PHONY: 1.25
1.25: ## Build EKS Optimized AL2 AMI - K8s 1.25
	$(MAKE) k8s kubernetes_version=1.25.6 kubernetes_build_date=2023-01-30 pull_cni_from_github=true

.PHONY: help
help: ## Display help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[\.a-zA-Z_0-9\-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
