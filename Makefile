KUBERNETES_VERSION ?= 1.10.3

DATE ?= $(shell date +%Y-%m-%d)

# Defaults to Amazon Linux 2 LTS AMI
# * use the us-west-2 minimal hvm image
# https://aws.amazon.com/amazon-linux-2/release-notes/
SOURCE_AMI_ID ?= ami-37efa14f

AWS_DEFAULT_REGION = us-west-2

all: ami

validate:
	packer validate eks-worker-al2.json

ami: validate
	packer build -var source_ami_id=$(SOURCE_AMI_ID) eks-worker-al2.json

release:
	AMI_ID=$(shell jq -r .builds[0].artifact_id manifest.json | cut -f2 -d':')
	DESCRIPTION=$(shell aws ec2 describe-images --image-id $(AMI_ID) --query "Images[0].Description" --output text)
	NAME=$(shell aws ec2 describe-images --image-id $(AMI_ID) --query "Images[0].Name" --output text)

	# TODO: Get new image id, name, description
	@echo "Copying image to us-east-1"
	aws --region us-east-1 ec2 copy-image \
		--source-region us-west-2 \
		--source-image-id $(AMI_ID) \
		--name $(AMI_NAME) \
		--description $(DESCRIPTION) \
		--query "ImageId" \
		--output text
	@echo "Sync the nodegroup yaml"
	@echo "aws s3 cp ./amazon-eks-nodegroup.yaml s3://amazon-eks/$(KUBERNETES_VERSION)/$(DATE)"
	@echo
	@echo "Update CloudFormation link in docs at"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/launch-workers.md"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/getting-started.md"
