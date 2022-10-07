PACKER_BINARY ?= packer
PACKER_VARIABLES := $(shell $(PACKER_BINARY) inspect -machine-readable eks-worker-al2.json | grep 'template-variable' | awk -F ',' '{print $$4}')

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

aws_region ?= $(AWS_DEFAULT_REGION)
binary_bucket_region ?= $(AWS_DEFAULT_REGION)
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
all: 1.20 1.21 1.22 1.23 ## Build all versions of EKS Optimized AL2 AMI

.PHONY: test
test: ## run the test-harness
	test/test-harness.sh

.PHONY: validate
validate: ## Validate packer config
	$(PACKER_BINARY) validate $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

.PHONY: k8s
k8s: validate ## Build default K8s version of EKS Optimized AL2 AMI
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build -timestamp-ui $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

# Build dates and versions taken from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

.PHONY: 1.20
1.20: ## Build EKS Optimized AL2 AMI - K8s 1.20
	$(MAKE) k8s kubernetes_version=1.20.15 kubernetes_build_date=2022-07-27 pull_cni_from_github=true

.PHONY: 1.21
1.21: ## Build EKS Optimized AL2 AMI - K8s 1.21
	$(MAKE) k8s kubernetes_version=1.21.14 kubernetes_build_date=2022-07-27 pull_cni_from_github=true

.PHONY: 1.22
1.22: ## Build EKS Optimized AL2 AMI - K8s 1.22
	$(MAKE) k8s kubernetes_version=1.22.12 kubernetes_build_date=2022-07-27 pull_cni_from_github=true

.PHONY: 1.23
1.23: ## Build EKS Optimized AL2 AMI - K8s 1.23
	$(MAKE) k8s kubernetes_version=1.23.9 kubernetes_build_date=2022-07-27 pull_cni_from_github=true

.PHONY: help
help: ## Display help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[\.a-zA-Z_0-9\-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
