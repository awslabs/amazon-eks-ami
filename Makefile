KUBERNETES_VERSION ?= 1.10.3

DATE ?= $(shell date +%Y-%m-%d)

AWS_DEFAULT_REGION = us-west-2

.PHONY: all validate ami

all: ami

validate:
	docker-compose run --rm -T packer validate eks-worker-al2.json

ami: validate
	docker-compose run --rm -T packer build \
		eks-worker-al2.json
