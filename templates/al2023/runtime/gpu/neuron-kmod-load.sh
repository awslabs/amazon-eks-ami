#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

INSTANCE_TYPE=$(imds /latest/meta-data/instance-type)

NEURON_MODULE_NAME="aws-neuronx"
if [[ "$INSTANCE_TYPE" =~ ^inf1 ]]; then
  echo "Using legacy module version"
  NEURON_MODULE_NAME="aws-neuronx-legacy"
fi

# For backwards compatibility, continue loading module unconditionally for now.
# TODO: determine if this should be loaded conditionally, more similar to nvidia driver handling
kmod-util load "$NEURON_MODULE_NAME"

# The neuron dkms module has a post install script that includes writing a modules-load configuration, 
# we disable automatic module loading by systemd based on the modules load config file to help ensure that it 
# is always this service that causes the module to be loaded
# Wirting an empty configuration ensures that even a lower priority config of the same name (e.g. in /usr/lib)
# is not picked up
sudo truncate -s 0 /etc/modules-load.d/neuron.conf