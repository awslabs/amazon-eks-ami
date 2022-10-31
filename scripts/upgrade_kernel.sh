#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "$KERNEL_VERSION" ]]; then
  KERNEL_VERSION=5.4

  echo "kernel_version is unset. Setting to $KERNEL_VERSION"
fi

if [[ $KERNEL_VERSION == "4.14" ]]; then
  sudo yum update -y kernel
elif [[ $KERNEL_VERSION == "5.4" ]]; then
  # Pinning Kernel to 5.4.209-116.367 since we're investigating issues with later Kernel versions which cause nodes to become Unready.
  # sudo amazon-linux-extras install -y kernel-5.4
  sudo amazon-linux-extras enable kernel-5.4=latest
  sudo yum -y install kernel-5.4.209-116.367.amzn2
  sudo yum install -y yum-plugin-versionlock
  sudo yum versionlock kernel-5.4*
elif [[ $KERNEL_VERSION == "5.10" ]]; then
  sudo amazon-linux-extras install -y kernel-5.10
else
  echo "$KERNEL_VERSION is not a valid kernel version"
  exit 1
fi

sudo reboot
