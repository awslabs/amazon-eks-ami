#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "$KERNEL_VERSION" ]]; then
  if vercmp "$KUBERNETES_VERSION" gteq "1.24.0"; then
    KERNEL_VERSION=5.10
    echo "kernel_version is unset. Setting to $KERNEL_VERSION based on Kubernetes version $KUBERNETES_VERSION."
  else
    KERNEL_VERSION=5.4
    echo "kernel_version is unset. Setting to $KERNEL_VERSION."
  fi
fi

if [[ $KERNEL_VERSION == "4.14" ]]; then
  sudo yum update -y kernel
elif [[ $KERNEL_VERSION == "5.4" ]]; then
  sudo amazon-linux-extras install -y kernel-5.4
elif [[ $KERNEL_VERSION == "5.10" ]]; then
  sudo amazon-linux-extras install -y kernel-5.10
else
  echo "$KERNEL_VERSION is not a valid kernel version"
  exit 1
fi

sudo reboot
