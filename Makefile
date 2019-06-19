DOCKER_VERSION ?= 18.06
KUBERNETES_BUILD_DATE ?= 2019-03-27
CNI_VERSION ?= v0.6.0
CNI_PLUGIN_VERSION ?= v0.7.5
ARCH ?= x86_64
BINARY_BUCKET_NAME ?= amazon-eks
SOURCE_AMI_OWNERS ?= 137112412989
OG_IMAGE_VERSION ?= 1.0.0
AMI_REGIONS ?= us-west-2,us-east-1

PACKER_BINARY ?= packer
AWS_BINARY ?= aws

ifeq ($(ARCH), arm64)
INSTANCE_TYPE ?= a1.large
else
INSTANCE_TYPE ?= m4.large
endif

DATE ?= $(shell date +%Y-%m-%d)

AWS_DEFAULT_REGION ?= us-west-2

T_RED := \e[0;31m
T_GREEN := \e[0;32m
T_YELLOW := \e[0;33m
T_RESET := \e[0m

.PHONY: all
all: 1.10 1.11 1.12

.PHONY: validate
validate:
	$(PACKER_BINARY) validate \
		-var instance_type=$(INSTANCE_TYPE) \
		eks-worker-al2.json

.PHONY: k8s
k8s: validate
	@echo "$(T_GREEN)Building AMI for version $(T_YELLOW)$(VERSION)$(T_GREEN) on $(T_YELLOW)$(ARCH)$(T_RESET)"
	$(eval SOURCE_AMI_ID := $(shell $(AWS_BINARY) ec2 describe-images \
		--output text \
		--filters \
			Name=owner-id,Values=$(SOURCE_AMI_OWNERS) \
			Name=virtualization-type,Values=hvm \
			Name=root-device-type,Values=ebs \
			Name=name,Values=amzn2-ami-minimal-hvm-* \
			Name=architecture,Values=$(ARCH) \
			Name=state,Values=available \
		--query 'max_by(Images[], &CreationDate).ImageId'))
	@if [ -z "$(SOURCE_AMI_ID)" ]; then\
		echo "$(T_RED)Failed to find candidate AMI!$(T_RESET)"; \
		exit 1; \
	fi
	$(PACKER_BINARY) build \
		-var instance_type=$(INSTANCE_TYPE) \
		-var kubernetes_version=$(VERSION) \
		-var kubernetes_build_date=$(KUBERNETES_BUILD_DATE) \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		-var arch=$(ARCH) \
		-var binary_bucket_name=$(BINARY_BUCKET_NAME) \
		-var cni_version=$(CNI_VERSION) \
		-var cni_plugin_version=$(CNI_PLUGIN_VERSION) \
		-var docker_version=$(DOCKER_VERSION) \
		-var og_image_version=$(OG_IMAGE_VERSION) \
		-var ami_regions=$(AMI_REGIONS) \
		eks-worker-al2.json

.PHONY: 1.10
1.10: validate
	$(MAKE) VERSION=1.10.13-01-eks k8s

.PHONY: 1.11
1.11: validate
	$(MAKE) VERSION=1.11.9 k8s

.PHONY: 1.12
1.12: validate
	$(MAKE) VERSION=1.12.7 k8s
