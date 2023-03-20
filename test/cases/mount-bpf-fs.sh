#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

export MOUNT_BPF_FS_DEBUG=true

echo "--> Should succeed if bpf type fs already exists"
function mount() {
  echo "none on /foo/bar type bpf (rw,nosuid,nodev,noexec,relatime,mode=700)"
}
export -f mount
EXIT_CODE=0
mount-bpf-fs || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got: $EXIT_CODE"
  exit 1
fi
export -nf mount

echo "--> Should succeed if mount point already exists"
function mount() {
  echo "none on /sys/fs/bpf type foo (rw,nosuid,nodev,noexec,relatime,mode=700)"
}
export -f mount
EXIT_CODE=0
mount-bpf-fs || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got: $EXIT_CODE"
  exit 1
fi
export -nf mount

echo "--> Should succeed if systemd unit already exists"
function mount() {
  echo "foo"
}
export -f mount
SYSTEMD_UNIT=/etc/systemd/system/sys-fs-bpf.mount
mkdir -p $(dirname $SYSTEMD_UNIT)
echo "foo" > $SYSTEMD_UNIT
EXIT_CODE=0
mount-bpf-fs || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got: $EXIT_CODE"
  exit 1
fi
export -nf mount
rm $SYSTEMD_UNIT
