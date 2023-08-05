#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "$KERNEL_VERSION" ]]; then
  if vercmp "$KUBERNETES_VERSION" gteq "1.24.0"; then
    KERNEL_VERSION=5.10
  else
    KERNEL_VERSION=5.4
  fi
  echo "kernel_version is unset. Setting to $KERNEL_VERSION based on Kubernetes version $KUBERNETES_VERSION."
fi

if [[ $KERNEL_VERSION == "4.14" ]]; then
  sudo yum update -y kernel
else
  sudo amazon-linux-extras install -y "kernel-${KERNEL_VERSION}"
fi

# enable pressure stall information
sudo grubby \
  --update-kernel=ALL \
  --args="psi=1"

# use the tsc clocksource by default
# https://repost.aws/knowledge-center/manage-ec2-linux-clock-source
sudo grubby \
  --update-kernel=ALL \
  --args="clocksource=tsc tsc=reliable"

sudo reboot
