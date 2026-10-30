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

# Existing state must survive the move onto the volume
mkdir -p /var/lib/kubelet
echo "seeded" > /var/lib/kubelet/seed

nodeadm init --daemon="" --config-source file://config.yaml

# Verify the volume itself is mounted at its mount target
VOLUME_UNIT=$(systemd-escape --path --suffix=mount /mnt/k8s-disks/ebs0)
assert::file-contains "/etc/systemd/system/${VOLUME_UNIT}" 'Where=/mnt/k8s-disks/ebs0'
systemctl is-active "${VOLUME_UNIT}"

# Verify each bind target is bind mounted from its subdirectory of the volume
for target in /var/lib/containerd /var/lib/kubelet /var/log/pods; do
  unit=$(systemd-escape --path --suffix=mount "${target}")
  assert::file-contains "/etc/systemd/system/${unit}" "What=/mnt/k8s-disks/ebs0/$(basename "${target}")"
  assert::file-contains "/etc/systemd/system/${unit}" "Where=${target}"
  assert::file-contains "/etc/systemd/system/${unit}" 'Options=bind'
  systemctl is-active "${unit}"
  if [ "$(stat -c %d "${target}")" != "$(stat -c %d /mnt/k8s-disks/ebs0)" ]; then
    echo "${target} is not on the EBS volume"
    exit 1
  fi
done

# Verify existing contents were copied onto the volume
assert::file-contains /var/lib/kubelet/seed 'seeded'
assert::file-contains /mnt/k8s-disks/ebs0/kubelet/seed 'seeded'
