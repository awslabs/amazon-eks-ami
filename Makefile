KUBERNETES_VERSION ?= 1.10.3

DATE ?= $(shell date +%Y-%m-%d)

AWS_DEFAULT_REGION = us-west-2

.PHONY: all validate ami 1.11 1.10

all: 1.11

validate:
	docker-compose run --rm -T packer validate eks-worker-al2.json

1.10: validate
	docker-compose run --rm -T packer build \
		-var binary_bucket_path=1.10.11/2018-12-06/bin/linux/amd64 \
		eks-worker-al2.json

1.11: validate
	docker-compose run --rm -T packer build \
		-var binary_bucket_path=1.11.5/2018-12-06/bin/linux/amd64 \
		eks-worker-al2.json
