#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.31.0

nodeadm init --skip run --config-source file://config.yaml

assert::json-files-equal /etc/eks/image-credential-provider/config.json expected-image-credential-provider-config-1.31.json

mock::kubelet 1.36.0

nodeadm init --skip run --config-source file://config.yaml

assert::json-files-equal /etc/eks/image-credential-provider/config.json expected-image-credential-provider-config.json
