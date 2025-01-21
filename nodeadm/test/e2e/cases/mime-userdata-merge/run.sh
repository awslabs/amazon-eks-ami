#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
# NOTE: test uses a kubelet version lower than 1.30, since the additional
# config will be written to a drop-in file in 1.30+
mock::kubelet 1.27.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config.json
