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

DOCKER_PACKER = docker run -v /mnt/credentials:/root/.aws/credentials \
	-e AWS_SHARED_CREDENTIALS_FILE=/root/.aws/credentials \
	-v `pwd`/:/workspace -w /workspace \
	876270261134.dkr.ecr.us-west-2.amazonaws.com/devops/packer:1.6.1

.PHONY: all validate ami 1.17 1.16 1.15 1.14 1.13 1.12 1.11 1.10

all: 1.19

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

1.15: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.15 \
		-var binary_bucket_path=1.15.11/2020-09-18/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.16: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.16 \
		-var binary_bucket_path=1.16.15/2020-11-02/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.17: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.17 \
		-var binary_bucket_path=1.17.12/2020-11-02/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.18: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.18 \
		-var binary_bucket_path=1.18.9/2020-11-02/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.19: validate
	$(DOCKER_PACKER) build \
		-var aws_region=$(AWS_REGION) \
		-var kubernetes_version=1.19 \
		-var binary_bucket_path=1.19.13/2021-09-02/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

