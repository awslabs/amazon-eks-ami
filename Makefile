KUBERNETES_VERSION ?= 1.10.3
DATE ?= $(shell date +%Y-%m-%d)

# Defaults to Amazon Linux 2 LTS Candidate AMI
SOURCE_AMI_us-east-1 = ami-d20657ad
SOURCE_AMI_us-west-2 = ami-37efa14f
REGION ?= us-west-2

SOURCE_AMI_ID ?= $(SOURCE_AMI_$(REGION))


all: ami

ami:
	packer build -var source_ami_id=$(SOURCE_AMI_ID) -var aws_region=$(REGION) eks-worker-al2.json

release:
	aws s3 cp ./amazon-eks-nodegroup.yaml s3://amazon-eks/$(KUBERNETES_VERSION)/$(DATE)
	@echo "Update CloudFormation link in docs at"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/launch-workers.md"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/getting-started.md"
