#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "$KERNEL_VERSION" ]]; then
  KERNEL_VERSION=5.10
  echo "kernel_version is unset. Setting to $KERNEL_VERSION based on Kubernetes version $KUBERNETES_VERSION."
fi

if [[ $KERNEL_VERSION == 4.14* ]]; then
  sudo yum install -y "kernel-${KERNEL_VERSION}*"
else
  KERNEL_MINOR_VERSION=$(echo ${KERNEL_VERSION} | cut -d. -f-2)
  sudo amazon-linux-extras enable "kernel-${KERNEL_MINOR_VERSION}"
  sudo yum install -y "kernel-${KERNEL_VERSION}*"
fi

sudo yum install -y "kernel-headers-${KERNEL_VERSION}*" "kernel-devel-${KERNEL_VERSION}*"

# enable pressure stall information
sudo grubby \
  --update-kernel=ALL \
  --args="psi=1"
