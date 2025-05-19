#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws aemm-g5-config.json
mock::kubelet 1.32.0
wait::dbus-ready

touch /usr/bin/nvidia-container-runtime

nodeadm init --skip run --config-source file://configv2.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-configv2.toml

nodeadm init --skip run --config-source file://configv3.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-configv3.toml
