KUBERNETES_VERSION ?= 1.10.3
DATE ?= $(shell date +%Y-%m-%d)
# Defaults to Amazon Linux 2 LTS Candidate AMI
SOURCE_AMI_ID ?= ami-8c3848f4

all: ami

ami:
	packer build -var source_ami_id=$(SOURCE_AMI_ID) eks-worker-al2.json

release:
	aws s3 cp ./amazon-eks-nodegroup.yaml s3://amazon-eks/$(KUBERNETES_VERSION)/$(DATE)
	@echo "Update CloudFormation link in docs at"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/launch-workers.md"
	@echo " - https://github.com/awsdocs/amazon-eks-user-guide/blob/master/doc_source/getting-started.md"
