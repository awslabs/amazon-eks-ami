#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ ! "$ENABLE_ACCELERATOR" =~ ^(nvidia|neuron)$ && "$ENABLE_EFA" != "true" ]]; then
  echo "Skipping worker accelerator post support - configuring multi-card interfaces"
  exit 0
fi

sudo mv $WORKING_DIR/accelerator/configure-multicard-interfaces.sh /etc/eks/
sudo mv $WORKING_DIR/accelerator/configure-multicard-interfaces.service /lib/systemd/system/
sudo systemctl enable configure-multicard-interfaces
