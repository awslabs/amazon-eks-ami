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

echo "--> Should default to true"
export KUBELET_VERSION=v1.27.0-eks-ba74326
MOUNT_BPF_FS_MOCK=$(mktemp)
function mount-bpf-fs() {
  echo "called" >> $MOUNT_BPF_FS_MOCK
}
export MOUNT_BPF_FS_MOCK
export -f mount-bpf-fs
EXIT_CODE=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  ipv4-cluster || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
if [ ! "$(cat $MOUNT_BPF_FS_MOCK)" = "called" ]; then
  echo "❌ Test Failed: expected mount-bpf-fs to be called once but it was not!"
  exit 1
fi
export -nf mount-bpf-fs

echo "--> Should be disabled by flag"
export KUBELET_VERSION=v1.27.0-eks-ba74326
MOUNT_BPF_FS_MOCK=$(mktemp)
function mount-bpf-fs() {
  echo "called" >> $MOUNT_BPF_FS_MOCK
}
export MOUNT_BPF_FS_MOCK
export -f mount-bpf-fs
EXIT_CODE=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --mount-bpf-fs false \
  ipv4-cluster || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
if [ "$(cat $MOUNT_BPF_FS_MOCK)" = "called" ]; then
  echo "❌ Test Failed: expected mount-bpf-fs to not be called but it was!"
  exit 1
fi
export -nf mount-bpf-fs
