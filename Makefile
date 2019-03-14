BUILD_TAG := $(or $(BUILD_TAG), $(shell date +%s))
SOURCE_AMI_ID ?= $(shell aws ec2 describe-images \
	--output text \
	--filters \
		Name=owner-id,Values=099720109477 \
		Name=virtualization-type,Values=hvm \
		Name=root-device-type,Values=ebs \
		Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-* \
		Name=architecture,Values=x86_64 \
		Name=state,Values=available \
	--query 'max_by(Images[], &CreationDate).ImageId')

AWS_DEFAULT_REGION = us-west-2

.PHONY: all validate ami 1.11 1.10

all: 1.11

validate:
	packer validate eks-worker-bionic.json

1.10: validate
	packer build \
		-color=false \
		-var kubernetes_version=1.10 \
		-var binary_bucket_path=1.10.13/2019-03-13/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.11: validate
	packer build \
		-color=false \
		-var kubernetes_version=1.11 \
		-var binary_bucket_path=1.11.8/2019-03-13/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var encrypted=true \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json
