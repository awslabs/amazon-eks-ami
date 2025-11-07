#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

MACHINE=$(uname -m)
readonly MACHINE
readonly EC2_GRID_DRIVER_S3_BUCKET="ec2-linux-nvidia-drivers"

function rpm_install() {
  local RPMS
  read -ra RPMS <<< "$@"
  echo "Pulling and installing local rpms from s3 bucket"
  for RPM in "${RPMS[@]}"; do
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${RPM} ${WORKING_DIR}/${RPM}
    sudo dnf localinstall -y ${WORKING_DIR}/${RPM}
  done
}

################################################################################
### Add repository #############################################################
################################################################################

## TODO: consider switching to the AL nvidia repository for all partitions
if [[ $(imds /latest/meta-data/services/partition) =~ ^aws-iso ]]; then
  sudo dnf install -y nvidia-release
  sudo sed -i 's/$dualstack//g' /etc/yum.repos.d/amazonlinux-nvidia.repo
else
  # Determine the domain based on the region
  if [[ "$AWS_REGION" =~ ^cn- ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  if [ -n "${NVIDIA_REPOSITORY:-}" ]; then
    sudo dnf config-manager --add-repo ${NVIDIA_REPOSITORY}
  else
    sudo dnf config-manager --add-repo https://developer.download.${DOMAIN}/compute/cuda/repos/amzn2023/${MACHINE}/cuda-amzn2023.repo
  fi

  # update all current .repo sources to enable gpgcheck
  sudo dnf config-manager --save --setopt=*.gpgcheck=1
  # enable the open module stream so that package installs can later be performed against it
  sudo dnf -y module enable nvidia-driver:${NVIDIA_DRIVER_MAJOR_VERSION}-open
fi

################################################################################
### Select install version #####################################################
################################################################################

echo "Resolving full driver version for ${NVIDIA_DRIVER_MAJOR_VERSION} drivers..."

LATEST_GRID_DRIVER_VERSION=$(aws s3 ls --recursive s3://${EC2_GRID_DRIVER_S3_BUCKET}/ \
  | grep -Eo "(NVIDIA-Linux-x86_64-)${NVIDIA_DRIVER_MAJOR_VERSION}\.[0-9]+\.[0-9]+(-grid-aws\.run)" \
  | cut -d'-' -f4 \
  | sort -V \
  | tail -1)

echo "Latest available Nvidia GRID driver runfile version: ${LATEST_GRID_DRIVER_VERSION}"

LATEST_OPEN_MODULE_VERSION=$(dnf repoquery --setopt=*.module_hotfixes=true --latest=1 --queryformat "%{version}" "kmod-nvidia-open-dkms-${NVIDIA_DRIVER_MAJOR_VERSION}*")

echo "Latest available Nvidia open module version: ${LATEST_OPEN_MODULE_VERSION}"

# The this script eventually builds and archives the nvidia proprietary, nvidia open, and nvidia grid
# kernel modules in /var/lib/dkms-archive. To ensure proper functionality, we need to enforce that
# all three kernel modules are on the same NVIDIA driver version so they are compatible with the same
# userspace components. If one of the open module or the grid driver runfile version are older, we
# use that version for all installations. Assumes that the open and proprietary module will always be
# available at the same version, and that each source will always eventually have the same versions.
if vercmp "$LATEST_OPEN_MODULE_VERSION" lteq "$LATEST_GRID_DRIVER_VERSION"; then
  readonly NVIDIA_DRIVER_FULL_VERSION="$LATEST_OPEN_MODULE_VERSION"
else
  readonly NVIDIA_DRIVER_FULL_VERSION="$LATEST_GRID_DRIVER_VERSION"
fi

if [[ -z "$NVIDIA_DRIVER_FULL_VERSION" ]]; then
  echo "ERROR: Could not determine the full nvidia driver version to install for major version $NVIDIA_DRIVER_MAJOR_VERSION"
  exit 1
fi

echo "Installing NVIDIA ${NVIDIA_DRIVER_FULL_VERSION} drivers..."

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

sudo dnf -y install dkms

function archive-open-kmods() {
  echo "Archiving open kmods"
  # The Nvidia CUDA repo uses module streams for providing kmod-nvidia* packages. The open-dkms stream is
  # enabled by default, so only the latest open driver package can be installed by default. Enabling module
  # hotfixes disables modular filtering, allowing us to find any package regardless of stream, more similar
  # to how the amazonlinux-nvidia repository functions
  sudo dnf -y --setopt=*.module_hotfixes=true install "kmod-nvidia-open-dkms-${NVIDIA_DRIVER_FULL_VERSION}"
  dkms status
  ls -la /var/lib/dkms/
  # The open kernel module name changed from nvidia-open to nvidia in 570.148.08
  # Remove and re-add dkms module with the correct name. This maintains the current install and archive behavior
  local NVIDIA_OPEN_VERSION
  NVIDIA_OPEN_VERSION=$(kmod-util module-version nvidia)

  # The DKMS package name differs between the RPM and the dkms.conf in the OSS kmod sources
  # TODO: can be removed if this is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/567
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

  sudo dnf -y remove --all nvidia-driver
  sudo dnf -y remove --all "kmod-nvidia-open*"
}

function archive-grid-kmod() {
  local NVIDIA_GRID_RUNFILE_KEY
  local GRID_INSTALLATION_TEMP_DIR
  local EXTRACT_DIR

  GRID_INSTALLATION_TEMP_DIR=$(mktemp -d)
  EXTRACT_DIR="${GRID_INSTALLATION_TEMP_DIR}/NVIDIA-GRID-extract"

  if [ "$MACHINE" != "x86_64" ]; then
    return
  fi

  echo "Archiving NVIDIA GRID kernel modules"
  NVIDIA_GRID_RUNFILE_KEY=$(aws s3 ls --recursive ${EC2_GRID_DRIVER_S3_BUCKET} \
    | grep "NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_FULL_VERSION}" \
    | sort -k1,2 \
    | tail -1 \
    | awk '{print $4}')

  if [[ -z "$NVIDIA_GRID_RUNFILE_KEY" ]]; then
    echo "ERROR: No GRID driver found for driver version ${NVIDIA_DRIVER_FULL_VERSION} in EC2 S3 bucket"
    exit 1
  fi

  echo "Found GRID runfile: ${NVIDIA_GRID_RUNFILE_KEY}"
  local GRID_RUNFILE_NAME
  GRID_RUNFILE_NAME=$(basename "${NVIDIA_GRID_RUNFILE_KEY}")

  echo "Downloading GRID driver runfile..."
  # This is the only command that requires the bucket name to actually just be the bucket (no prefix) b/c of how the
  # s3 ls recursive output dumps the full object key regardless of the supplied prefix
  aws s3 cp "s3://${EC2_GRID_DRIVER_S3_BUCKET%%/*}/${NVIDIA_GRID_RUNFILE_KEY}" "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_NAME}"
  chmod +x "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_NAME}"
  echo "Extracting NVIDIA GRID driver runfile..."
  sudo "${GRID_INSTALLATION_TEMP_DIR}/${GRID_RUNFILE_NAME}" --extract-only --target "${EXTRACT_DIR}"

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
  echo "Archiving proprietary kmods"
  # The Nvidia CUDA repo uses module streams for providing kmod-nvidia* packages. The open-dkms stream is
  # enabled by default, so only the latest open driver package can be installed by default. Enabling module
  # hotfixes disables modular filtering, allowing us to find any package regardless of stream, more similar
  # to how the amazonlinux-nvidia repository functions
  sudo dnf -y --setopt=*.module_hotfixes=true install "kmod-nvidia-latest-dkms-${NVIDIA_DRIVER_FULL_VERSION}"

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

echo "ib_umad" | sudo tee -a /etc/modules-load.d/ib-umad.conf
sudo dnf -y install \
  libibumad \
  infiniband-diags \
  nvlsm

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
  # versions of nvidia-imex < 580 use nvidia-imex-<major-version>-<full-version>
  sudo dnf -y install "nvidia-imex-${NVIDIA_DRIVER_MAJOR_VERSION}-${NVIDIA_DRIVER_FULL_VERSION}"
else
  sudo dnf -y install "nvidia-fabricmanager-${NVIDIA_DRIVER_FULL_VERSION}"
  sudo dnf -y install "nvidia-imex-${NVIDIA_DRIVER_FULL_VERSION}"
fi

sudo dnf -y install nvidia-container-toolkit
sudo dnf -y install "nvidia-persistenced-${NVIDIA_DRIVER_FULL_VERSION}"
sudo dnf -y install "nvidia-driver-cuda-${NVIDIA_DRIVER_FULL_VERSION}"
if [[ "$NVIDIA_DRIVER_MAJOR_VERSION" -ge "580" ]]; then
  sudo dnf -y install \
    "libnvidia-fbc-${NVIDIA_DRIVER_FULL_VERSION}" \
    "nvidia-driver-${NVIDIA_DRIVER_FULL_VERSION}" \
    "nvidia-libXNVCtrl-devel-${NVIDIA_DRIVER_FULL_VERSION}" \
    "nvidia-settings-${NVIDIA_DRIVER_FULL_VERSION}" \
    "nvidia-xconfig-${NVIDIA_DRIVER_FULL_VERSION}" \
    "xorg-x11-nvidia-${NVIDIA_DRIVER_FULL_VERSION}"
fi

sudo systemctl enable nvidia-fabricmanager
sudo systemctl enable nvidia-persistenced
