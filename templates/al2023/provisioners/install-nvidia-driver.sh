#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

function is-isolated-partition() {
  [[ $(imds /latest/meta-data/services/partition) =~ ^aws-iso ]]
}

function rpm_install() {
  local RPMS
  read -ra RPMS <<< "$@"
  echo "Pulling and installing local rpms from s3 bucket"
  for RPM in "${RPMS[@]}"; do
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${RPM} ${WORKING_DIR}/${RPM}
    sudo dnf localinstall -y ${WORKING_DIR}/${RPM}
  done
}

echo "Installing NVIDIA ${NVIDIA_DRIVER_MAJOR_VERSION} drivers..."

# The AL2023 GPU AMI currently builds and archives the following nvidia kernel modules
# in /var/lib/dkms-archive: nvidia, nvidia-open, nvidia-open-grid. To maintain the stability
# of the AMI, we want to ensure that all three kernel modules (and also the userspace modules)
# are on the same NVIDIA driver version. Currently, the script installs the NVIDIA GRID drivers
# first and decides the full NVIDIA driver version that the AMI will adhere to
if [[ "$AWS_REGION" == "us-isof-south-1" || "$AWS_REGION" == "eusc-de-east-1" || "$AWS_REGION" == "eu-isoe-west-1" ]]; then
  EC2_GRID_DRIVER_S3_BUCKET="${BINARY_BUCKET_NAME}"
  GRID_DRIVER_S3_SCAN_PATH="s3://${EC2_GRID_DRIVER_S3_BUCKET}/bin/nvidia-grid-drivers/"
else
  EC2_GRID_DRIVER_S3_BUCKET="ec2-linux-nvidia-drivers"
  GRID_DRIVER_S3_SCAN_PATH="s3://${EC2_GRID_DRIVER_S3_BUCKET}/"
fi

NVIDIA_DRIVER_FULL_VERSION=$(aws s3 ls --recursive ${GRID_DRIVER_S3_SCAN_PATH} \
  | grep -Eo "(NVIDIA-Linux-x86_64-)${NVIDIA_DRIVER_MAJOR_VERSION}\.[0-9]+\.[0-9]+(-grid-aws\.run)" \
  | cut -d'-' -f4 \
  | sort -V \
  | tail -1)

if [[ -z "$NVIDIA_DRIVER_FULL_VERSION" ]]; then
  echo "ERROR: Could not determine the full nvidia driver version to install"
  exit 1
fi

################################################################################
### Add repository #############################################################
################################################################################
function get_cuda_al2023_x86_repo() {
  if [[ $AWS_REGION == cn-* ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  echo "https://developer.download.${DOMAIN}/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo"
}

# Determine the domain based on the region
if is-isolated-partition; then
  sudo dnf install -y nvidia-release
  sudo sed -i 's/$dualstack//g' /etc/yum.repos.d/amazonlinux-nvidia.repo

  rpm_install "opencl-filesystem-1.0-5.el7.noarch.rpm" "ocl-icd-2.2.12-1.el7.x86_64.rpm"
else
  if [ -n "${NVIDIA_REPOSITORY:-}" ]; then
    sudo dnf config-manager --add-repo ${NVIDIA_REPOSITORY}
  else
    sudo dnf config-manager --add-repo "$(get_cuda_al2023_x86_repo)"
  fi

  # update all current .repo sources to enable gpgcheck
  sudo dnf config-manager --save --setopt=*.gpgcheck=1
fi

################################################################################
### Install drivers ############################################################
################################################################################
sudo mv ${WORKING_DIR}/gpu/gpu-ami-util /usr/bin/
sudo mv ${WORKING_DIR}/gpu/kmod-util /usr/bin/

sudo mkdir -p /etc/dkms
echo "MAKE[0]=\"'make' -j$(grep -c processor /proc/cpuinfo) module\"" | sudo tee /etc/dkms/nvidia.conf

KERNEL_PACKAGE="kernel"
if [[ "$(uname -r)" == 6.12.* ]]; then
  KERNEL_PACKAGE="kernel6.12"
fi
sudo dnf -y install \
  "${KERNEL_PACKAGE}-devel" \
  "${KERNEL_PACKAGE}-headers" \
  "${KERNEL_PACKAGE}-modules-extra" \
  "${KERNEL_PACKAGE}-modules-extra-common"

sudo dnf versionlock 'kernel*'

# Install dkms dependency from amazonlinux repo
sudo dnf -y install patch

if is-isolated-partition; then
  sudo dnf -y install dkms
else
  # Install dkms from the cuda repo
  if [[ "$(uname -m)" == "x86_64" ]]; then
    sudo dnf -y --disablerepo="*" --enablerepo="cuda*" install dkms
  else
    sudo dnf -y remove dkms
    sudo dnf config-manager --add-repo "$(get_cuda_al2023_x86_repo)"
    sudo dnf -y --disablerepo="*" --enablerepo="cuda*" install dkms
    sudo dnf config-manager --set-disabled cuda-amzn2023-x86_64
    sudo rm /etc/yum.repos.d/cuda-amzn2023.repo
  fi
fi

function archive-open-kmods() {
  local NVIDIA_OPEN_MODULE
  echo "Archiving open kmods"

  if is-isolated-partition; then
    sudo dnf -y install "kmod-nvidia-open-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}.*"
  else
    # Output of `sudo dnf module provides -q kmod-nvidia-open-dkms-570.172.08* | grep Module` is:
    # Module   : nvidia-driver:570-open:20251009011129:f132e61741:x86_64
    # There is also a latest module stream that may provide the same package version, so we select only
    # the one with the version in the name
    NVIDIA_OPEN_MODULE=$(sudo dnf module provides -q kmod-nvidia-open-dkms-${NVIDIA_DRIVER_FULL_VERSION}* | grep Module | awk -F' : ' '{print $2}' | grep "$NVIDIA_DRIVER_MAJOR_VERSION")
    sudo dnf -y module install ${NVIDIA_OPEN_MODULE}
  fi
  dkms status
  ls -la /var/lib/dkms/
  # The DKMS package name differs between the RPM and the dkms.conf in the OSS kmod sources
  # TODO: can be removed if this is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/567

  # The open kernel module name changed from nvidia-open to nvidia in 570.148.08
  # Remove and re-add dkms module with the correct name. This maintains the current install and archive behavior
  local NVIDIA_OPEN_VERSION
  NVIDIA_OPEN_VERSION=$(kmod-util module-version nvidia)

  # Sanity check to have consistent NVIDIA driver versions
  if [[ "$NVIDIA_OPEN_VERSION" != "$NVIDIA_DRIVER_FULL_VERSION" ]]; then
    echo "ERROR: NVIDIA open driver version ($NVIDIA_OPEN_VERSION) does not match GRID driver version ($NVIDIA_DRIVER_FULL_VERSION)"
    echo "All NVIDIA drivers must be on the same version."
    exit 1
  fi

  sudo dkms remove "nvidia/$NVIDIA_OPEN_VERSION" --all
  sudo sed -i 's/PACKAGE_NAME="nvidia"/PACKAGE_NAME="nvidia-open"/' /usr/src/nvidia-$NVIDIA_OPEN_VERSION/dkms.conf
  sudo mv /usr/src/nvidia-$NVIDIA_OPEN_VERSION /usr/src/nvidia-open-$NVIDIA_OPEN_VERSION
  sudo dkms add -m nvidia-open -v $NVIDIA_OPEN_VERSION
  sudo dkms build -m nvidia-open -v $NVIDIA_OPEN_VERSION
  sudo dkms install -m nvidia-open -v $NVIDIA_OPEN_VERSION

  sudo kmod-util archive nvidia-open

  KMOD_MAJOR_VERSION=$(sudo kmod-util module-version nvidia-open | cut -d. -f1)
  SUPPORTED_DEVICE_FILE="${WORKING_DIR}/gpu/nvidia-open-supported-devices-${KMOD_MAJOR_VERSION}.txt"
  sudo mv "${SUPPORTED_DEVICE_FILE}" /etc/eks/

  sudo kmod-util remove nvidia-open

  if is-isolated-partition; then
    sudo dnf -y remove --all nvidia-driver
    sudo dnf -y remove --all "kmod-nvidia-open*"
  else
    sudo dnf -y module remove --all ${NVIDIA_OPEN_MODULE}
    sudo dnf -y module reset ${NVIDIA_OPEN_MODULE}
  fi
}

function archive-grid-kmod() {
  local MACHINE
  local NVIDIA_GRID_RUNFILE_NAME
  local GRID_INSTALLATION_TEMP_DIR
  local EXTRACT_DIR

  GRID_INSTALLATION_TEMP_DIR=$(mktemp -d)
  EXTRACT_DIR="${GRID_INSTALLATION_TEMP_DIR}/NVIDIA-GRID-extract"

  MACHINE=$(uname -m)
  if [ "$MACHINE" != "x86_64" ]; then
    return
  fi

  echo "Archiving NVIDIA GRID kernel modules for major version ${NVIDIA_DRIVER_MAJOR_VERSION}"
  NVIDIA_GRID_RUNFILE_NAME=$(aws s3 ls --recursive ${GRID_DRIVER_S3_SCAN_PATH} \
    | grep "NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_FULL_VERSION}" \
    | sort -k1,2 \
    | tail -1 \
    | awk '{print $4}')

  if [[ -z "$NVIDIA_GRID_RUNFILE_NAME" ]]; then
    echo "ERROR: No GRID driver found for driver version ${NVIDIA_DRIVER_FULL_VERSION} in EC2 S3 bucket"
    exit 1
  fi

  echo "Found GRID runfile: ${NVIDIA_GRID_RUNFILE_NAME}"
  local GRID_RUNFILE_LOCAL_NAME
  GRID_RUNFILE_LOCAL_NAME=$(basename "${NVIDIA_GRID_RUNFILE_NAME}")

  echo "Downloading GRID driver runfile..."
  aws s3 cp "s3://${EC2_GRID_DRIVER_S3_BUCKET}/${NVIDIA_GRID_RUNFILE_NAME}" "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_LOCAL_NAME}"
  chmod +x "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_LOCAL_NAME}"
  echo "Extracting NVIDIA GRID driver runfile..."
  sudo "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_LOCAL_NAME}" --extract-only --target "${EXTRACT_DIR}"

  pushd "${EXTRACT_DIR}"

  echo "Installing NVIDIA GRID kernel modules..."
  sudo ./nvidia-installer \
    --dkms \
    --kernel-module-type open \
    --silent || sudo cat /var/log/nvidia-installer.log

  # Manual DKMS registration with package name changed to `nvidia-open-grid`
  sudo dkms remove "nvidia/$NVIDIA_DRIVER_FULL_VERSION" --all
  sudo sed -i 's/PACKAGE_NAME="nvidia"/PACKAGE_NAME="nvidia-open-grid"/' /usr/src/nvidia-$NVIDIA_DRIVER_FULL_VERSION/dkms.conf
  sudo mv /usr/src/nvidia-$NVIDIA_DRIVER_FULL_VERSION /usr/src/nvidia-open-grid-$NVIDIA_DRIVER_FULL_VERSION
  sudo dkms add -m nvidia-open-grid -v $NVIDIA_DRIVER_FULL_VERSION
  sudo dkms build -m nvidia-open-grid -v $NVIDIA_DRIVER_FULL_VERSION
  sudo dkms install -m nvidia-open-grid -v $NVIDIA_DRIVER_FULL_VERSION

  sudo kmod-util archive nvidia-open-grid
  sudo kmod-util remove nvidia-open-grid
  sudo rm -rf /usr/src/nvidia-open-grid*

  popd
  sudo rm -rf "${GRID_INSTALLATION_TEMP_DIR}"
}

function archive-proprietary-kmod() {
  local NVIDIA_PROPRIETARY_MODULE
  echo "Archiving proprietary kmods"

  if is-isolated-partition; then
    sudo dnf -y install "kmod-nvidia-latest-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}.*"
  else
    # Output of `sudo dnf module provides -q kmod-nvidia-latest-dkms-570.172.08* | grep Module` is:
    # Module   : nvidia-driver:570-dkms:20251009011129:61f77618b4:x86_64
    # There is also a latest module stream that may provide the same package version, so we select only
    # the one with the version in the name
    NVIDIA_PROPRIETARY_MODULE=$(sudo dnf module provides -q kmod-nvidia-latest-dkms-${NVIDIA_DRIVER_FULL_VERSION}* | grep Module | awk -F' : ' '{print $2}' | grep "$NVIDIA_DRIVER_MAJOR_VERSION")
    sudo dnf -y module install ${NVIDIA_PROPRIETARY_MODULE}
  fi

  local NVIDIA_PROPRIETARY_VERSION
  NVIDIA_PROPRIETARY_VERSION=$(kmod-util module-version nvidia)

  if [[ "$NVIDIA_PROPRIETARY_VERSION" != "$NVIDIA_DRIVER_FULL_VERSION" ]]; then
    echo "ERROR: NVIDIA proprietary driver version ($NVIDIA_PROPRIETARY_VERSION) does not match GRID driver version ($NVIDIA_DRIVER_FULL_VERSION)"
    echo "All NVIDIA drivers must be on the same version. GRID driver determines the version."
    exit 1
  fi

  sudo kmod-util archive nvidia
  sudo kmod-util remove nvidia
  sudo rm -rf /usr/src/nvidia*
}

archive-grid-kmod
archive-open-kmods
archive-proprietary-kmod

################################################################################
### Install NVLSM ##############################################################
################################################################################
# https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#systems-using-fourth-generation-nvswitches

# TODO: install unconditionally once availability is guaranteed
if ! is-isolated-partition; then
  echo "ib_umad" | sudo tee -a /etc/modules-load.d/ib-umad.conf
  sudo dnf -y install \
    libibumad \
    infiniband-diags \
    nvlsm
fi

################################################################################
### Prepare for nvidia init ####################################################
################################################################################

sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.sh /etc/eks/
sudo mv ${WORKING_DIR}/gpu/nvidia-kmod-load.service /etc/systemd/system/nvidia-kmod-load.service
sudo mv ${WORKING_DIR}/gpu/set-nvidia-clocks.service /etc/systemd/system/set-nvidia-clocks.service
sudo systemctl daemon-reload
sudo systemctl enable nvidia-kmod-load.service
sudo systemctl enable set-nvidia-clocks.service

################################################################################
### Install other dependencies #################################################
################################################################################
if [[ "$NVIDIA_DRIVER_MAJOR_VERSION" -lt "580" ]]; then
  # versions before 580 used to have a dash between fabric and manager
  sudo dnf -y install "nvidia-fabric-manager-${NVIDIA_DRIVER_FULL_VERSION}"
else
  sudo dnf -y install "nvidia-fabricmanager-${NVIDIA_DRIVER_FULL_VERSION}"
fi
# versions of nvidia-imex < 580 use nvidia-imex-<major-version>-<full-version>
sudo dnf -y install "nvidia-imex-${NVIDIA_DRIVER_MAJOR_VERSION}*"

# NVIDIA Container toolkit needs to be locally installed for isolated partitions, also install NVIDIA-Persistenced
if is-isolated-partition; then
  sudo dnf -y install nvidia-container-toolkit
  sudo dnf -y install "nvidia-persistenced-${NVIDIA_DRIVER_FULL_VERSION}"
  sudo dnf -y install "nvidia-driver-cuda-${NVIDIA_DRIVER_FULL_VERSION}"
  # TODO: standardize this across partitions
  if [[ "$NVIDIA_DRIVER_MAJOR_VERSION" -ge "580" ]]; then
    sudo dnf -y install \
      "libnvidia-fbc-${NVIDIA_DRIVER_FULL_VERSION}" \
      "nvidia-driver-${NVIDIA_DRIVER_FULL_VERSION}" \
      "nvidia-libXNVCtrl-devel-${NVIDIA_DRIVER_FULL_VERSION}" \
      "nvidia-settings-${NVIDIA_DRIVER_FULL_VERSION}" \
      "nvidia-xconfig-${NVIDIA_DRIVER_FULL_VERSION}" \
      "xorg-x11-nvidia-${NVIDIA_DRIVER_FULL_VERSION}"
  fi
else
  sudo dnf -y install nvidia-container-toolkit
fi

sudo systemctl enable nvidia-fabricmanager
sudo systemctl enable nvidia-persistenced
