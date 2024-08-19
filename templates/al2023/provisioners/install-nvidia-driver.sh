#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ACCELERATOR_VENDOR" != "nvidia" ]; then
  exit 0
fi 
echo "Installing Nvidia ${NVIDIA_MAJOR_DRIVER_VERSION} drivers..."

################################################################################
### Add repository #############################################################
################################################################################
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

sudo sed -i 's/gpgcheck=0/gpgcheck=1/g' /etc/yum.repos.d/nvidia-container-toolkit.repo /etc/yum.repos.d/cuda-amzn2023.repo 

################################################################################
### Install drivers ############################################################
################################################################################
sudo mkdir -p /etc/dkms
echo "MAKE[0]=\"'make' -j$(grep -c processor /proc/cpuinfo) module\"" | sudo tee /etc/dkms/nvidia.conf
sudo dnf -y install kernel-modules-extra.x86_64

function archive-open-kmods(){
  sudo dnf --setopt=install_weak_deps=False -y module install nvidia-driver:${NVIDIA_MAJOR_DRIVER_VERSION}-open
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

function archive-proprietary-kmod(){
  sudo dnf --setopt=install_weak_deps=False -y module install nvidia-driver:${NVIDIA_MAJOR_DRIVER_VERSION}-dkms
  sudo kmod-util archive nvidia
  sudo kmod-util remove nvidia
}

archive-open-kmods
archive-proprietary-kmod

################################################################################
### Prepare for nvidia bootstrap ###############################################
################################################################################

sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/initialize_nvidia_clock.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/bootstrap_gpu.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/bootstrap_gpu.service /etc/systemd/system/bootstrap_gpu.service
sudo systemctl daemon-reload
sudo systemctl enable bootstrap_gpu


################################################################################
### Install other dependencies #################################################
################################################################################
sudo dnf --setopt=install_weak_deps=False -y install nvidia-fabric-manager nvidia-container-toolkit

sudo systemctl enable nvidia-fabricmanager
sudo systemctl enable nvidia-persistenced

################################################################################
### Display license agreement ##################################################
################################################################################
echo '#!/bin/sh

echo -n "
#############################################################
By using the EKS GPU Optimized AMI, you agree to the NVIDIA Cloud End User License Agreement
https://s3.amazonaws.com/EULA/NVidiaEULAforAWS.pdf.
#############################################################
"'| sudo tee /etc/eks/nvidia-eula

sudo chmod +x /etc/eks/nvidia-eula

echo "[Unit]
Description=Display Nvidia driver EULA

[Service]
Type=oneshot
ExecStart=/etc/eks/nvidia-eula

[Install]
WantedBy=basic.target
"| sudo tee /etc/systemd/system/nvidia-eula.service

sudo chmod +x /etc/systemd/system/nvidia-eula.service

sudo systemctl daemon-reload
sudo systemctl enable nvidia-eula
