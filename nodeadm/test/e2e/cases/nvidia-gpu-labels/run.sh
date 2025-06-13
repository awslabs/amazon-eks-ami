#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.32.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::file-not-contains /etc/eks/kubelet/environment '--node-labels=nvidia.com/gpu.present'
assert::file-contains /etc/eks/kubelet/environment '--node-labels=foo=bar'

# since we cannot modify the kernel sysfs paths, we bind mount our mock
# directory on top of an existing pci device. the only requirement for the check
# is that the vendor ID file is correct.
pci_mock_dst=/sys/bus/pci/devices/$(ls /sys/bus/pci/devices/ | head -n 1)
pci_mock_src=$(mktemp -d)
echo "0x10de" > $pci_mock_src/vendor
mount --bind $pci_mock_src $pci_mock_dst

nodeadm init --skip run --config-source file://config.yaml

assert::file-contains /etc/eks/kubelet/environment '--node-labels=nvidia.com/gpu.present=true'
assert::file-contains /etc/eks/kubelet/environment '--node-labels=foo=bar'
