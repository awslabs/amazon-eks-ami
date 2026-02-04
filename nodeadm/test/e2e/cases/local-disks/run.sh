#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.34.0

# These loopback devices play oddly with docker, so only use them in this one test.
# Create fake NVMe instance storage devices using loopback devices
mkdir -p /dev/disk/by-id
for i in 0 1; do
  loop_file="/tmp/fake-nvme-${i}.img"
  # xfs requires min size of 300M, so use 2x160M.
  truncate -s 160M "$loop_file"
  loop_dev=$(losetup --find --show "$loop_file")
  ln -sf "$loop_dev" "/dev/disk/by-id/nvme-Amazon_EC2_NVMe_Instance_Storage_AWS${i}"
done

nodeadm init --daemon="" --config-source file://config.yaml

if ! [ -e /dev/md/kubernetes ]; then
  echo "RAID device /dev/md/kubernetes was not created"
  exit 1
fi

raid_level=$(mdadm --detail /dev/md/kubernetes | grep -oP 'Raid Level : raid\K\d+')
if [ "$raid_level" != "0" ]; then
  echo "Expected RAID level 0, got $raid_level"
  exit 1
fi

if ! mountpoint -q /mnt/k8s-disks/0; then
  echo "/mnt/k8s-disks/0 is not mounted"
  exit 1
fi

md_dev=$(realpath /dev/md/kubernetes)
pods_source=$(findmnt -n -o SOURCE /var/log/pods)
if [[ "$pods_source" != "${md_dev}[/pods]" ]]; then
  echo "/var/log/pods is not mounted on RAID, got: $pods_source"
  exit 1
fi

echo "RAID0 setup verified successfully"
