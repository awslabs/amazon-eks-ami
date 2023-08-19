VERSION ?= $(shell hack/version.sh)

.PHONY: bootstrap
bootstrap:
	go build -ldflags="-X 'main.version=$(VERSION)'" -o build/bootstrap
