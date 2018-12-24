DATE ?= $(shell date +%Y-%m-%d)

# Defaults to Amazon Linux 2 LTS AMI
# * use the us-west-2 minimal hvm image
# https://aws.amazon.com/amazon-linux-2/release-notes/
SOURCE_AMI_ID ?= $(shell aws ec2 describe-images \
	--output text \
	--filters \
		Name=owner-id,Values=137112412989 \
		Name=virtualization-type,Values=hvm \
		Name=root-device-type,Values=ebs \
		Name=name,Values=amzn2-ami-minimal-hvm-* \
		Name=architecture,Values=x86_64 \
		Name=state,Values=available \
	--query 'max_by(Images[], &CreationDate).ImageId')

AWS_DEFAULT_REGION ?= us-west-2
USE_COMPOSE ?= false

ifeq ($(USE_COMPOSE), true)
	PACKER := docker-compose run --rm -T packer
else
	PACKER := packer
endif

.PHONY: all validate ami 1.11 1.10

all: 1.11

validate:
	$(PACKER) validate eks-worker-al2.json

1.10: validate
	$(PACKER) build \
		-var aws_region=${AWS_DEFAULT_REGION} \
		-var binary_bucket_path=1.10.11/2018-12-06/bin/linux/amd64 \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-al2.json

1.11: validate
	$(PACKER) build \
		-var aws_region=${AWS_DEFAULT_REGION} \
		-var binary_bucket_path=1.11.5/2018-12-06/bin/linux/amd64 \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-al2.json
