#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::kubelet 1.28.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::files-equal /var/lib/kubelet/kubeconfig expected-kubeconfig.yaml
assert::files-equal /etc/kubernetes/kubelet/config.json.d/10-defaults.conf expected-kubelet-config.json
