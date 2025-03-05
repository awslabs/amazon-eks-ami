#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.31.0
nodeadm init --skip run --config-source file://config.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-config-pre-1.32.toml

# enable_cdi defaults to true in 1.32+
mock::kubelet 1.32.0
nodeadm init --skip run --config-source file://config.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-config.toml
