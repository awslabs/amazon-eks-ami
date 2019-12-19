PACKER_BINARY ?= packer
PACKER_VARIABLES := ami_name binary_bucket_name kubernetes_version kubernetes_build_date docker_version cni_version cni_plugin_version source_ami_id arch instance_type
AWS_DEFAULT_REGION ?= us-west-2

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

ami_name ?= amazon-eks-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d')
arch ?= x86_64
ifeq ($(arch), arm64)
instance_type ?= a1.large
else
instance_type ?= m4.large
endif

T_RED := \e[0;31m
T_GREEN := \e[0;32m
T_YELLOW := \e[0;33m
T_RESET := \e[0m

.PHONY: all
all: 1.11 1.12 1.13 1.14

.PHONY: validate
validate:
	$(PACKER_BINARY) validate $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)=$($(packerVar)),)) eks-worker-al2.json

.PHONY: k8s
k8s: validate
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)=$($(packerVar)),)) eks-worker-al2.json

# Build dates and versions taken from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

.PHONY: 1.11
1.11:
	$(MAKE) k8s kubernetes_version=1.11.10 kubernetes_build_date=2019-12-13

.PHONY: 1.12
1.12:
	$(MAKE) k8s kubernetes_version=1.12.10 kubernetes_build_date=2019-12-13

.PHONY: 1.13
1.13:
	$(MAKE) k8s kubernetes_version=1.13.12 kubernetes_build_date=2019-12-13

.PHONY: 1.14
1.14:
	$(MAKE) k8s kubernetes_version=1.14.8 kubernetes_build_date=2019-12-13
