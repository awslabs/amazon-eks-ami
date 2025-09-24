#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.31.0

CONFIG_DIR=$(mktemp -d)

# empty dir should not fail overall chain
nodeadm init --skip run --config-source file://config.yaml --config-source file://$CONFIG_DIR

cp config.yaml $CONFIG_DIR/config.yaml

# assert all forms of inputting the chain are valid
nodeadm init --skip run --config-source file://$CONFIG_DIR
nodeadm init --skip run --config-source file://config.yaml --config-source file://$CONFIG_DIR
nodeadm init --skip run --config-source file://config.yaml,file://$CONFIG_DIR
