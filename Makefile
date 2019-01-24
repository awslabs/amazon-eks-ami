BUILD_TAG := $(or $(BUILD_TAG), $(shell date +%s))
KUBERNETES_VERSION ?= 1.10.3

DATE ?= $(shell date +%Y-%m-%d)

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
		-var binary_bucket_path=1.10.11/2018-12-06/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json

1.11: validate
	packer build \
		-color=false \
		-var binary_bucket_path=1.11.5/2018-12-06/bin/linux/amd64 \
		-var build_tag=$(BUILD_TAG) \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-bionic.json
