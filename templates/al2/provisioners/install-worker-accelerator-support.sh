#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ ! "$ENABLE_ACCELERATOR" =~ ^(nvidia|neuron)$ && "$ENABLE_EFA" != "true" ]]; then
  echo "Skipping worker accelerator support - pciutils and oci-add-hooks"
  exit 0
fi

sudo yum install -y \
    pciutils \
    oci-add-hooks
