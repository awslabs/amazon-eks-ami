#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.32.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml
assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config.json
