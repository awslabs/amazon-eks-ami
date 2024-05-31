#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::files-equal /etc/containerd/base-runtime-spec.json expected-base-runtime-spec.json
