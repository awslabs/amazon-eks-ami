#!/usr/bin/env bash

set -o pipefail
set -o nounset

validate_directory_selinux_contexts() {
  local DIR=$1
  echo "Validating SELinux contexts in $DIR"

  unverified_files=$(matchpathcon -V $DIR/* | grep -v verified)

  if [ -n "$unverified_files" ]; then
    echo "$unverified_files"
    unverified_files_count=$(echo "$unverified_files" | wc -l)
    echo "Validation error: Found $unverified_files_count files with incorrect SELinux context in folder $DIR"
    exit 1
  fi
  echo "Validated SELinux contexts in $DIR"
}

sudo restorecon -R -v /usr/bin
validate_directory_selinux_contexts /usr/bin

sudo restorecon -R -v /etc/systemd/system
validate_directory_selinux_contexts /etc/systemd/system

sudo restorecon -R -v /etc/eks
validate_directory_selinux_contexts /etc/eks

# The NVIDIA driver trees surface at /usr through overlay mounts and at /etc through a boot-time
# copy. These equivalencies give each tree path the label its /usr or /etc counterpart would get.
if [ -d /opt/nvidia ]; then
  for NVIDIA_TREE in lts pb current; do
    sudo semanage fcontext -a -e /usr "/opt/nvidia/${NVIDIA_TREE}/usr"
    sudo semanage fcontext -a -e /etc "/opt/nvidia/${NVIDIA_TREE}/etc"
  done
  sudo restorecon -R /opt/nvidia
  # validated against lts and pb
  for NVIDIA_TREE in lts pb; do
    validate_directory_selinux_contexts "/opt/nvidia/${NVIDIA_TREE}/etc"
    validate_directory_selinux_contexts "/opt/nvidia/${NVIDIA_TREE}/usr/bin"
  done
fi
