#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.35.0
mock::setup-local-disks

# Create a loopback device to simulate an EBS volume
dd if=/dev/zero of=/tmp/ebs-disk.img bs=1M count=100
LOOP_DEV=$(losetup -f --show /tmp/ebs-disk.img)

# Update config to use the assigned loop device
sed -i "s|/dev/loop0|${LOOP_DEV}|g" config.yaml

# Mock lsblk to report EBS model for loopback devices
cat > /mock/bin/lsblk << 'SCRIPT'
#!/usr/bin/env bash
if echo "$@" | grep -q "MODEL"; then
  echo "Amazon Elastic Block Store"
else
  /usr/bin/lsblk "$@"
fi
SCRIPT
chmod +x /mock/bin/lsblk
nodeadm init --daemon="" --config-source file://config.yaml

# Verify EBS mounted containerd via systemd
assert::file-contains /etc/systemd/system/var-lib-containerd.mount 'Where=/var/lib/containerd'
assert::file-contains /etc/systemd/system/var-lib-containerd.mount 'Type=ext4'
systemctl is-active var-lib-containerd.mount

# Verify setup-local-disks was still called for NVMe RAID
assert::file-contains /var/log/setup-local-disks.log 'raid0'
