AWS_REGION ?= us-west-2
BUILD_TAG := $(or $(BUILD_TAG), $(shell date +%s))
SOURCE_AMI_ID ?= $(shell aws \
	--region $(AWS_REGION) \
	ec2 describe-images \
	--output text \
	--filters \
		Name=owner-id,Values=099720109477 \
		Name=virtualization-type,Values=hvm \
		Name=root-device-type,Values=ebs \
		Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* \
		Name=architecture,Values=x86_64 \
		Name=state,Values=available \
	--query 'max_by(Images[], &CreationDate).ImageId')

DOCKER_PACKER = docker run -v /mnt/.aws/credentials:/root/.aws/credentials \
	-e AWS_SHARED_CREDENTIALS_FILE=/root/.aws/credentials \
	-v `pwd`/:/workspace -w /workspace\
	hashicorp/packer:light

.PHONY: all validate ami 1.13 1.12 1.11 1.10

all: 1.12

validate:
	$(DOCKER_PACKER) validate /workspace/eks-worker-bionic.json

1.10: validate
	$(DOCKER_PACKER) build \
		-color=false \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.10 \
		-var binary_bucket_path=1.10.13/2019-03-27/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.11: validate
	$(DOCKER_PACKER) build \
		-color=false \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.11 \
		-var binary_bucket_path=1.11.9/2019-03-27/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.12: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.12 \
		-var binary_bucket_path=1.12.7/2019-03-27/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json


1.13: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.13 \
		-var binary_bucket_path=1.13.12/2020-04-16/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.14: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.14 \
		-var binary_bucket_path=1.14.9/2020-04-16/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json