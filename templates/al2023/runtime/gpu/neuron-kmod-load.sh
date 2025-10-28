#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

readonly AMAZON_VENDOR_CODE="1d0f"
# Based on https://github.com/aws-neuron/aws-neuron-driver/blob/fca19f7df31b44cbbffaf121230a66df6f59d118/neuron_device.h#L36-L39
readonly INF1_DEVICE_IDS=("7064" "7065" "7066" "7067")

NEURON_MODULE_NAME="aws-neuronx"

for DEVICE_ID in "${INF1_DEVICE_IDS[@]}"; do
  MATCHED_DEVICES=$(lspci -d "${AMAZON_VENDOR_CODE}:${DEVICE_ID}" | wc -l)
  if [[ "$MATCHED_DEVICES" -gt 0 ]]; then
    NEURON_MODULE_NAME="aws-neuronx-legacy"
    break
  fi
done

echo $NEURON_MODULE_NAME

# For backwards compatibility, continue loading module unconditionally for now.
# TODO: determine if this should be loaded only on instances with neuron devices, more similar to nvidia driver handling
kmod-util load "$NEURON_MODULE_NAME"

# The neuron dkms module has a post install script that includes writing a modules-load configuration, we disable
# automatic module loading by systemd based on the modules load config file to help ensure that it is always this
# service that causes the module to be loaded. Writing an empty configuration ensures that even a lower priority
# config of the same name (e.g. in /usr/lib) is not picked up
sudo rm -f /etc/modules-load.d/neuron.conf
sudo ln -s /dev/null /etc/modules-load.d/neuron.conf
