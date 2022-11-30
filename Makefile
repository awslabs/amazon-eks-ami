# commands:
P := packer

#Fluence Edited Variables
AWS_DEFAULT_REGION = us-west-2
build_tag := $(or $(BUILD_TAG), $(shell date +%s))
encrypted := true
PACKER_BINARY = docker run -v /mnt/credentials:/root/.aws/credentials \
	-e AWS_SHARED_CREDENTIALS_FILE=/root/.aws/credentials \
	-v `pwd`/:/workspace -w /workspace \
	876270261134.dkr.ecr.us-west-2.amazonaws.com/devops/packer:1.6.1
PACKER_VARIABLES := aws_region ami_name binary_bucket_name binary_bucket_region kubernetes_version kubernetes_build_date kernel_version docker_version containerd_version runc_version cni_plugin_version source_ami_id source_ami_owners source_ami_filter_name arch instance_type security_group_id additional_yum_repos pull_cni_from_github sonobuoy_e2e_registry build_tag encrypted


#PACKER_BINARY ?= packer
#PACKER_VARIABLES := aws_region ami_name binary_bucket_name binary_bucket_region kubernetes_version kubernetes_build_date kernel_version docker_version containerd_version runc_version cni_plugin_version source_ami_id source_ami_owners source_ami_filter_name arch instance_type security_group_id additional_yum_repos pull_cni_from_github sonobuoy_e2e_registry

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

aws_region ?= $(AWS_DEFAULT_REGION)
binary_bucket_region ?= $(AWS_DEFAULT_REGION)
arch ?= x86_64
ifeq ($(arch), arm64)
instance_type ?= m6g.large
ami_name ?= amazon-eks-arm64-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d%H%M%S')
else
instance_type ?= m4.large
ami_name ?= amazon-eks-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d%H%M%S')
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

.PHONY: all 1.18 1.19 1.20 1.21 1.22
all: 1.21

all-validate: 1.21

.PHONY: k8s
k8s: validate
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

# Build dates and versions taken from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

.PHONY: 1.19-validate
1.19-validate:
	$(MAKE) ci-validate kubernetes_version=1.19.15 kubernetes_build_date=2021-11-10 pull_cni_from_github=true

.PHONY: 1.19-build
1.19-build:
	$(MAKE) ci-build kubernetes_version=1.19.15 kubernetes_build_date=2021-11-10 pull_cni_from_github=true

.PHONY: 1.20-validate
1.20-validate:
	$(MAKE) ci-validate kubernetes_version=1.20.11 kubernetes_build_date=2021-11-10 pull_cni_from_github=true

.PHONY: 1.20-build
1.20-build:
	$(MAKE) ci-build kubernetes_version=1.20.11 kubernetes_build_date=2021-11-10 pull_cni_from_github=true

.PHONY: 1.21
1.21:
	$(MAKE) ci-build kubernetes_version=1.21.14 kubernetes_build_date=2022-10-31 pull_cni_from_github=true

.PHONY: 1.22
1.22:
	$(MAKE) ci-build kubernetes_version=1.22.6 kubernetes_build_date=2022-03-09 pull_cni_from_github=true

# Circle CI pipeline
.PHONY: ci-valiedate
ci-validate:
	$(P) validate $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

.PHONY: ci-build
ci-build:
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(P) build $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json