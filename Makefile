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

all: ami

validate:
	packer validate eks-worker-al2.json

createInstanceProfile:
	aws cloudformation validate-template --template-body file://builder-instance-profile.yaml
	aws cloudformation create-stack --stack-name nvidia-amazon-eks-ami-builder-instance-profile --template-body file://builder-instance-profile.yaml

ami: validate
	packer build -on-error=ask -var source_ami_id=$(SOURCE_AMI_ID) eks-worker-al2.json
