#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.35.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::file-not-contains /etc/eks/kubelet/environment '--node-labels=nvidia.com/gpu.present'
assert::file-contains /etc/eks/kubelet/environment '--node-labels=foo=bar'

# mock a pci device with the nvidia vendor-id.
mock::pci-device "0x10de"

nodeadm init --skip run --config-source file://config.yaml

assert::file-contains /etc/eks/kubelet/environment '--node-labels=nvidia.com/gpu.present=true'
assert::file-contains /etc/eks/kubelet/environment '--node-labels=foo=bar'

# the label is only applied start from Kubernetes 1.35+

mock::kubelet 1.34.0

nodeadm init --skip run --config-source file://config.yaml

assert::file-not-contains /etc/eks/kubelet/environment '--node-labels=nvidia.com/gpu.present=true'
assert::file-contains /etc/eks/kubelet/environment '--node-labels=foo=bar'
