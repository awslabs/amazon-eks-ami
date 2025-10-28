#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

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

################################################################################
### Install helpers ############################################################
################################################################################

sudo mv ${WORKING_DIR}/gpu/kmod-util /usr/bin/

################################################################################
### Archive 2.21 driver ########################################################
################################################################################

# Install and archive v2.21.x of the neuron driver as a legacy driver for inf1 support
# https://awsdocs-neuron.readthedocs-hosted.com/en/latest/about-neuron/announcements/neuron2.x/announce-eos-neuron-driver-support-inf1.html
sudo dnf install -y aws-neuronx-dkms-2.21*
LEGACY_VERSION=$(kmod-util module-version aws-neuronx)

sudo dkms remove "aws-neuronx/$LEGACY_VERSION" --all
# Rename to aws-neuronx-legacy so the correct version can be easily loaded at runtime
sudo sed -i 's/PACKAGE_NAME=.*/PACKAGE_NAME="aws-neuronx-legacy"/' /usr/src/aws-neuronx-${LEGACY_VERSION}/dkms.conf
sudo mv /usr/src/aws-neuronx-${LEGACY_VERSION} /usr/src/aws-neuronx-legacy-${LEGACY_VERSION}
# Disable "dkms autoinstall" from loading this module, this avoids automatic loading on boot by dkms.service
# and allows neuron-kmod-load.service to always load the correct version for the machine instead
sudo sed -i s/^AUTOINSTALL=.*/AUTOINSTALL=no/g /usr/src/aws-neuronx-legacy-${LEGACY_VERSION}/dkms.conf
sudo dkms add -m aws-neuronx-legacy -v $LEGACY_VERSION
sudo dkms build -m aws-neuronx-legacy -v $LEGACY_VERSION
sudo dkms install -m aws-neuronx-legacy -v $LEGACY_VERSION

# Archive, remove, and uninstall the driver
sudo kmod-util archive aws-neuronx-legacy
sudo kmod-util remove aws-neuronx-legacy
sudo dnf remove -y aws-neuronx-dkms

################################################################################
### Archive new driver #########################################################
################################################################################

# This one should be installed last because it's what most and all new instance types
# will use, so we kepe it loaded to offer boot time optimization for most uses
sudo dnf install -y aws-neuronx-dkms
DRIVER_VERSION=$(kmod-util module-version aws-neuronx)

# Disable "dkms autoinstall" from loading this module, this avoids automatic loading on boot by dkms.service
# and allows neuron-kmod-load.service to always load the correct version for the machine instead
sudo sed -i s/^AUTOINSTALL=.*/AUTOINSTALL=no/g "/var/lib/dkms/aws-neuronx/${DRIVER_VERSION}/source/dkms.conf"

# Archive but do not remove the driver
sudo kmod-util archive aws-neuronx

# Versionlock the new one to avoid unintentional installs of the driver
sudo dnf versionlock aws-neuronx-dkms

################################################################################
### Install other dependencies #################################################
################################################################################

sudo dnf install -y aws-neuronx-tools

################################################################################
### Prepare for boot ###########################################################
################################################################################

# Disable automatic module loading by systemd based on the modules load config file
# Writing an empty configuration ensures that even a lower priority config (e.g. in /usr/lib) is not picked up
sudo rm -f /etc/modules-load.d/neuron.conf
sudo ln -s /dev/null /etc/modules-load.d/neuron.conf

sudo mv ${WORKING_DIR}/gpu/neuron-kmod-load.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/neuron-kmod-load.service /etc/systemd/system/neuron-kmod-load.service
sudo systemctl daemon-reload
sudo systemctl enable neuron-kmod-load.service

# The postremove script used by the neuron module calls rmmod instead of the standard modrobe -r,
# which can causes the module to still show up in lsmod and fail later checks in the validate.sh provisioner
sudo rmmod neuron
