#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.31.0
nodeadm init --skip run --config-source file://configv2.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-config-pre-1.32.toml

# enable_cdi defaults to true in 1.32+
mock::kubelet 1.32.0
nodeadm init --skip run --config-source file://configv2.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-config.toml

if nodeadm init --skip run --config-source file://configv3.yaml; then 
    echo "bootstrap should not succeed if cx pass property belongs to containerd configuration version 3 when using containerd 1.7.*"
    exit 1
fi
