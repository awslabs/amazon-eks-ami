#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ ! "$ENABLE_ACCELERATOR" =~ ^(nvidia|neuron)$ && "$ENABLE_EFA" != "true" ]]; then
  echo "Skipping worker accelerator support: pciutils, oci-add-hooks, gpu-ami-util, kmod-util, and multi-card interfaces systemd service "
  exit 0
fi

sudo yum install -y pciutils oci-add-hooks

sudo mv $WORKING_DIR/accelerator/gpu-ami-util /usr/bin/
sudo mv $WORKING_DIR/accelerator/kmod-util /usr/bin/

sudo mv $WORKING_DIR/accelerator/configure-multicard-interfaces.sh /etc/eks/
sudo mv $WORKING_DIR/accelerator/configure-multicard-interfaces.service /lib/systemd/system/
sudo systemctl enable configure-multicard-interfaces
