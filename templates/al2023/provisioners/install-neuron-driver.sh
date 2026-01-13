#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

readonly PACKAGE_CACHE_PATH="/var/cache/eks/packages"

if [ "$ENABLE_ACCELERATOR" != "neuron" ]; then
  exit 0
fi

################################################################################
### Add repository #############################################################
################################################################################
sudo tee /etc/yum.repos.d/neuron.repo << EOF
[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
gpgcheck=1
gpgkey=https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB
metadata_expire=0
EOF

# Manually install the GPG key, verifies repository can be reached
sudo rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB

################################################################################
### Cache packages for conditional install at boot #############################
################################################################################
# TODO: remove this section if inf1 is not supported

# Install and remove aws-neuronx-dkms-2.21.x to ensure all of its dependencies are
# pre-installed
sudo dnf install -y aws-neuronx-dkms-2.21.*
sudo dnf remove -y --noautoremove aws-neuronx-dkms

# Cache the 2.21.x rpm for contidtional boot-time install
sudo dnf download aws-neuronx-dkms-2.21.*
sudo mkdir -p "$PACKAGE_CACHE_PATH"
sudo mv aws-neuronx-dkms-2.21.*.rpm "${PACKAGE_CACHE_PATH}/"

sudo mv ${WORKING_DIR}/gpu/neuron-package-install.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/neuron-package-install.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable neuron-package-install.service

################################################################################
### Install packages ###########################################################
################################################################################
KERNEL_PACKAGE="kernel"
if [[ "$(uname -r)" == 6.12.* ]]; then
  KERNEL_PACKAGE="kernel6.12"
fi
sudo dnf -y install \
  "${KERNEL_PACKAGE}-devel" \
  "${KERNEL_PACKAGE}-headers"

sudo dnf versionlock 'kernel*'

sudo dnf install -y aws-neuronx-dkms aws-neuronx-tools
