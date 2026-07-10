#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.35.0

# Create a loopback device to simulate an EBS volume
dd if=/dev/zero of=/tmp/ebs-disk.img bs=1M count=100
LOOP_DEV=$(losetup -f --show /tmp/ebs-disk.img)

# Update config to use the assigned loop device
sed -i "s|/dev/loop0|${LOOP_DEV}|g" config.yaml

nodeadm init --daemon="" --config-source file://config.yaml

# Verify the systemd mount unit was created and is active
assert::file-contains /etc/systemd/system/var-lib-kubelet.mount 'Where=/var/lib/kubelet'
assert::file-contains /etc/systemd/system/var-lib-kubelet.mount 'Type=ext4'

# Verify the mount is active
systemctl is-active var-lib-kubelet.mount
