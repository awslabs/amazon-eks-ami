#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

#Detect Isolated partitions
function is-isolated-partition() {
  PARTITION=$(imds /latest/meta-data/services/partition)
  NON_ISOLATED_PARTITIONS=("aws" "aws-cn" "aws-us-gov")
  for NON_ISOLATED_PARTITION in "${NON_ISOLATED_PARTITIONS[@]}"; do
    if [ "${NON_ISOLATED_PARTITION}" = "${PARTITION}" ]; then
      return 1
    fi
  done
  return 0
}

function rpm_install() {
  local RPMS=($@)
  echo "Pulling and installing local rpms from s3 bucket"
  for RPM in "${RPMS[@]}"; do
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${RPM} ${WORKING_DIR}/${RPM}
    sudo dnf localinstall -y ${WORKING_DIR}/${RPM}
  done
}

function install-nvidia-container-toolkit() {
  # The order of these RPMs is important, as they have dependencies on each other
  RPMS=("libnvidia-container1-1.17.1-1.x86_64.rpm" "nvidia-container-toolkit-base-1.17.1-1.x86_64.rpm" "libnvidia-container-tools-1.17.1-1.x86_64.rpm" "nvidia-container-toolkit-1.17.1-1.x86_64.rpm")
  for RPM in "${RPMS[@]}"; do
    echo "pulling and installing rpms: (${RPM}) from s3 bucket: (${BINARY_BUCKET_NAME}) in region: (${BINARY_BUCKET_REGION})"
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${RPM} ${WORKING_DIR}/${RPM}
    echo "installing rpm: ${WORKING_DIR}/${RPM}"
    sudo rpm -ivh ${WORKING_DIR}/${RPM}
  done
}

echo "Installing NVIDIA ${NVIDIA_DRIVER_MAJOR_VERSION} drivers..."

################################################################################
### Add repository #############################################################
################################################################################
# Determine the domain based on the region
if is-isolated-partition; then
  aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/amzn2023-nvidia.repo ${WORKING_DIR}/amzn2023-nvidia.repo

  sudo dnf config-manager --add-repo ${WORKING_DIR}/amzn2023-nvidia.repo
  rpm_install "opencl-filesystem-1.0-5.el7.noarch.rpm" "ocl-icd-2.2.12-1.el7.x86_64.rpm"

else
  if [[ $AWS_REGION == cn-* ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  sudo dnf config-manager --add-repo https://developer.download.${DOMAIN}/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
  sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo

  sudo sed -i 's/gpgcheck=0/gpgcheck=1/g' /etc/yum.repos.d/nvidia-container-toolkit.repo /etc/yum.repos.d/cuda-amzn2023.repo
fi

################################################################################
### Install drivers ############################################################
################################################################################
sudo mv ${WORKING_DIR}/gpu/gpu-ami-util /usr/bin/
sudo mv ${WORKING_DIR}/gpu/kmod-util /usr/bin/

sudo mkdir -p /etc/dkms
echo "MAKE[0]=\"'make' -j$(grep -c processor /proc/cpuinfo) module\"" | sudo tee /etc/dkms/nvidia.conf
sudo dnf -y install kernel-modules-extra.x86_64

function archive-open-kmods() {
  if is-isolated-partition; then
    sudo dnf -y install "kmod-nvidia-open-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}*"
  else
    sudo dnf -y module install nvidia-driver:${NVIDIA_DRIVER_MAJOR_VERSION}-open
  fi
  # The DKMS package name differs between the RPM and the dkms.conf in the OSS kmod sources
  # TODO: can be removed if this is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/567
  sudo sed -i 's/PACKAGE_NAME="nvidia"/PACKAGE_NAME="nvidia-open"/g' /var/lib/dkms/nvidia-open/$(kmod-util module-version nvidia-open)/source/dkms.conf

  sudo kmod-util archive nvidia-open

  KMOD_MAJOR_VERSION=$(sudo kmod-util module-version nvidia-open | cut -d. -f1)
  SUPPORTED_DEVICE_FILE="${WORKING_DIR}/gpu/nvidia-open-supported-devices-${KMOD_MAJOR_VERSION}.txt"
  sudo mv "${SUPPORTED_DEVICE_FILE}" /etc/eks/

  sudo kmod-util remove nvidia-open

  if is-isolated-partition; then
    sudo dnf -y remove --all nvidia-driver
  else
    sudo dnf -y module remove --all nvidia-driver
    sudo dnf -y module reset nvidia-driver
  fi
}

function archive-proprietary-kmod() {
  if is-isolated-partition; then
    sudo dnf -y install "kmod-nvidia-latest-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}*"
  else
    sudo dnf -y module install nvidia-driver:${NVIDIA_DRIVER_MAJOR_VERSION}-dkms
  fi
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
sudo dnf -y install nvidia-fabric-manager

# NVIDIA Container toolkit needs to be locally installed for isolated partitions
if is-isolated-partition; then
  install-nvidia-container-toolkit
else
  sudo dnf -y install nvidia-container-toolkit
fi

sudo systemctl enable nvidia-fabricmanager
sudo systemctl enable nvidia-persistenced
