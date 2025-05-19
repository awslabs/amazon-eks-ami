#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

touch /usr/bin/nvidia-container-runtime

nodeadm init --skip run --config-source file://configv2.yaml
assert::files-equal /etc/containerd/config.toml expected-containerd-config.toml

if nodeadm init --skip run --config-source file://configv3.yaml; then
  echo "bootstrap should not succeed if cx pass property belongs to containerd configuration version 3 when using containerd 1.7.*"
  exit 1
fi
