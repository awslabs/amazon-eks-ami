#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

readonly PACKAGE_CACHE_PATH="/var/cache/eks/packages"

readonly AMAZON_VENDOR_CODE="1d0f"
# Based on https://github.com/aws-neuron/aws-neuron-driver/blob/fca19f7df31b44cbbffaf121230a66df6f59d118/neuron_device.h#L36-L39
readonly INF1_DEVICE_IDS=("7064" "7065" "7066" "7067")

function is-inf1() {
  for DEVICE_ID in "${INF1_DEVICE_IDS[@]}"; do
    MATCHED_DEVICES=$(lspci -d "${AMAZON_VENDOR_CODE}:${DEVICE_ID}" | wc -l)
    if [[ "$MATCHED_DEVICES" -gt 0 ]]; then
      return 0
    fi
  done

  return 1
}

# the aws-neuronx-dkms module has a pre-install script that calls
# on update-pciids, which will hang if called from a node
# that cannot reach https://pci-ids.ucw.cz/v2.2/pci.ids
# the values pulled by the install at build time can be used
# in lieu of this
function update-pciids() {
  echo "update-pciids called: doing nothing"
}

function installed-neuron-driver-version() {
  rpm -q aws-neuronx-dkms --queryformat '%{VERSION}'
}

if is-inf1 && [[ $(installed-neuron-driver-version) != 2.21.* ]]; then
  echo "downgrading driver to 2.21"
  # "dnf downgrade" would fail because the post remove script for the package
  # does not fully remove the module, and then the post install script for the
  # downgraded version fails because of an attempt to probe an older version of
  # a loaded module without --force. relying on the rpm cli directly makes the
  # operations more intuitive
  export -f update-pciids
  rpm --erase aws-neuronx-dkms
  rpm -i "${PACKAGE_CACHE_PATH}/aws-neuronx-dkms-2.21.*.rpm"
else
  echo "nothing to do!"
fi
