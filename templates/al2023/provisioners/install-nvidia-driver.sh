#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi
echo "Installing NVIDIA ${NVIDIA_DRIVER_MAJOR_VERSION} drivers..."

################################################################################
### Add repository #############################################################
################################################################################
# Determine the domain based on the region
if [[ $AWS_REGION == cn-* ]]; then
  DOMAIN="nvidia.cn"
else
  DOMAIN="nvidia.com"
fi

sudo dnf config-manager --add-repo https://developer.download.${DOMAIN}/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sudo sed -i 's/gpgcheck=0/gpgcheck=1/g' /etc/yum.repos.d/nvidia-container-toolkit.repo /etc/yum.repos.d/cuda-amzn2023.repo

################################################################################
### Install drivers ############################################################
################################################################################
sudo mv ${WORKING_DIR}/gpu/gpu-ami-util /usr/bin/
sudo mv ${WORKING_DIR}/gpu/kmod-util /usr/bin/

sudo mkdir -p /etc/dkms
echo "MAKE[0]=\"'make' -j$(grep -c processor /proc/cpuinfo) module\"" | sudo tee /etc/dkms/nvidia.conf
sudo dnf -y install kernel-modules-extra.x86_64

function archive-open-kmods() {
  sudo dnf -y module install nvidia-driver:${NVIDIA_DRIVER_MAJOR_VERSION}-open
  # The DKMS package name differs between the RPM and the dkms.conf in the OSS kmod sources
  # TODO: can be removed if this is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/567
  sudo sed -i 's/PACKAGE_NAME="nvidia"/PACKAGE_NAME="nvidia-open"/g' /var/lib/dkms/nvidia-open/$(kmod-util module-version nvidia-open)/source/dkms.conf

  sudo kmod-util archive nvidia-open

  KMOD_MAJOR_VERSION=$(sudo kmod-util module-version nvidia-open | cut -d. -f1)
  SUPPORTED_DEVICE_FILE="${WORKING_DIR}/gpu/nvidia-open-supported-devices-${KMOD_MAJOR_VERSION}.txt"
  sudo mv "${SUPPORTED_DEVICE_FILE}" /etc/eks/

  sudo kmod-util remove nvidia-open

  sudo dnf -y module remove --all nvidia-driver
  sudo dnf -y module reset nvidia-driver
}

function archive-proprietary-kmod() {
  sudo dnf -y module install nvidia-driver:${NVIDIA_DRIVER_MAJOR_VERSION}-dkms
  sudo kmod-util archive nvidia
  sudo kmod-util remove nvidia
}

archive-open-kmods
archive-proprietary-kmod

################################################################################
### Prepare for nvidia init ####################################################
################################################################################

sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/set-nvidia-clocks.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.service /etc/systemd/system/nvidia-kmod-load.service
sudo mv ${WORKING_DIR}/gpu/set-nvidia-clocks.service /etc/systemd/system/set-nvidia-clocks.service
sudo systemctl daemon-reload
sudo systemctl enable nvidia-kmod-load.service
sudo systemctl enable set-nvidia-clocks.service

################################################################################
### Install other dependencies #################################################
################################################################################
sudo dnf -y install nvidia-fabric-manager nvidia-container-toolkit

sudo systemctl enable nvidia-fabricmanager
sudo systemctl enable nvidia-persistenced
