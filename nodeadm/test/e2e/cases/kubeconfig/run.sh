#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.29.0
nodeadm init --skip run --config-source file://config.yaml
assert::files-equal /var/lib/kubelet/kubeconfig expected-kubeconfig.yaml

mock::kubelet 1.35.0
nodeadm init --skip run --config-source file://config.yaml
assert::files-equal /var/lib/kubelet/kubeconfig expected-kubeconfig.yaml
