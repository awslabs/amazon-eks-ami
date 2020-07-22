PACKER_BINARY ?= packer
PACKER_VARIABLES := aws_region ami_name binary_bucket_name binary_bucket_region kubernetes_version kubernetes_build_date docker_version cni_version cni_plugin_version source_ami_id source_ami_owners arch instance_type security_group_id additional_yum_repos pull_cni_from_github enable_fips_mode

K8S_VERSION_PARTS := $(subst ., ,$(kubernetes_version))
K8S_VERSION_MINOR := $(word 1,${K8S_VERSION_PARTS}).$(word 2,${K8S_VERSION_PARTS})

aws_region ?= $(AWS_DEFAULT_REGION)
binary_bucket_region ?= $(AWS_DEFAULT_REGION)
ami_name ?= amazon-eks-node-$(K8S_VERSION_MINOR)-v$(shell date +'%Y%m%d')
arch ?= x86_64
ifeq ($(arch), arm64)
instance_type ?= a1.large
else
instance_type ?= m4.large
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
all: 1.14 1.15 1.16 1.17

.PHONY: validate
validate:
	$(PACKER_BINARY) validate $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

.PHONY: k8s
k8s: validate
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(kubernetes_version)$(T_GREEN) on $(T_YELLOW)$(arch)$(T_RESET)"
	$(PACKER_BINARY) build $(foreach packerVar,$(PACKER_VARIABLES), $(if $($(packerVar)),--var $(packerVar)='$($(packerVar))',)) eks-worker-al2.json

# Build dates and versions taken from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

.PHONY: 1.14
1.14:
	$(MAKE) k8s kubernetes_version=1.14.9 kubernetes_build_date=2020-07-08 pull_cni_from_github=true

.PHONY: 1.14-fips
1.14-fips:
	$(MAKE) k8s ami_name=amazon-eks-node-fips-1.14.9-v$(shell date +'%Y%m%d') kubernetes_version=1.14.9 kubernetes_build_date=2020-07-08 pull_cni_from_github=true enable_fips_mode=true

.PHONY: 1.15
1.15:
	$(MAKE) k8s kubernetes_version=1.15.11 kubernetes_build_date=2020-07-08 pull_cni_from_github=true

.PHONY: 1.15-fips
1.15-fips:
	$(MAKE) k8s ami_name=amazon-eks-node-fips-1.15.11-v$(shell date +'%Y%m%d') kubernetes_version=1.15.11 kubernetes_build_date=2020-07-08 pull_cni_from_github=true enable_fips_mode=true

.PHONY: 1.16
1.16:
	$(MAKE) k8s kubernetes_version=1.16.12 kubernetes_build_date=2020-07-08 pull_cni_from_github=true

.PHONY: 1.16-fips
1.16-fips:
	$(MAKE) k8s ami_name=amazon-eks-node-fips-1.16.12-v$(shell date +'%Y%m%d') kubernetes_version=1.16.12 kubernetes_build_date=2020-07-08 pull_cni_from_github=true enable_fips_mode=true

.PHONY: 1.17
1.17:
	$(MAKE) k8s kubernetes_version=1.17.7 kubernetes_build_date=2020-07-08 pull_cni_from_github=true

.PHONY: 1.17-fips
1.17-fips:
	$(MAKE) k8s ami_name=amazon-eks-node-fips-1.17.7-v$(shell date +'%Y%m%d') kubernetes_version=1.17.7 kubernetes_build_date=2020-07-08 pull_cni_from_github=true enable_fips_mode=true
