KUBERNETES_VERSION ?= 1.10.3

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

AWS_DEFAULT_REGION = us-west-2

.PHONY: all validate ami 1.11 1.10

all: 1.11

validate:
	packer validate eks-worker-al2.json

1.10: validate
	packer build \
		-var kubernetes_version=1.10 \
		-var binary_bucket_path=1.10.11/2018-12-06/bin/linux/amd64 \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-al2.json

1.11: validate
	packer build \
		-var kubernetes_version=1.11 \
		-var binary_bucket_path=1.11.5/2018-12-06/bin/linux/amd64 \
		-var source_ami_id=$(SOURCE_AMI_ID) \
		eks-worker-al2.json
