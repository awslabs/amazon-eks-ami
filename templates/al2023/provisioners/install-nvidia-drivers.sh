#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

################################################################################
### Validate Required Arguments ################################################
################################################################################
validate_env_set() {
  (
    set +o nounset

    if [ -z "${!1}" ]; then
      echo "Packer variable '$1' was not set. Aborting"
      exit 1
    fi
  )
}

validate_env_set AWS_REGION
validate_env_set EC2_GRID_DRIVER_S3_BUCKET
validate_env_set WORKING_DIR
validate_env_set NVIDIA_DRIVER_LTS_VERSION
validate_env_set NVIDIA_DRIVER_PB_VERSION

MACHINE=$(uname -m)
readonly MACHINE

readonly NVIDIA_TREE_ROOT="/opt/nvidia"

# shellcheck disable=SC1090
source "${WORKING_DIR}/helpers/nvidia-kmods.sh"
# shellcheck disable=SC1090
source "${WORKING_DIR}/helpers/nvidia-userspace.sh"

################################################################################
### Add repository #############################################################
################################################################################

## TODO: consider switching to the AL nvidia repository for all partitions
if [[ $(imds /latest/meta-data/services/partition) =~ ^aws-iso ]]; then
  sudo dnf install -y nvidia-release
  sudo dnf install -y nvidia-repo-s3
  sudo sed -i 's/$dualstack//g' /etc/yum.repos.d/amazonlinux-nvidia.repo
else
  # Determine the domain based on the region
  if [[ "$AWS_REGION" =~ ^cn- ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  if [ -n "${NVIDIA_REPOSITORY:-}" ]; then
    sudo dnf config-manager --add-repo "${NVIDIA_REPOSITORY}"
  else
    sudo dnf config-manager --add-repo "https://developer.download.${DOMAIN}/compute/cuda/repos/amzn2023/${MACHINE}/cuda-amzn2023.repo"
  fi

  # update all current .repo sources to enable gpgcheck
  sudo dnf config-manager --save --setopt=*.gpgcheck=1
fi

# dnf records repo keys in the rpmdb on install, not on download,
# so we don't get a sig verification by default.
# Import all repos since NVIDIA_REPOSITORY can be any url, so its unreliable to pin a repo-id.
# Cheap and idempotent.
dnf config-manager --dump '*' | sed -n 's/^gpgkey = //p' | tr ',' '\n' | sed 's/^ *//' | sort -u \
  | xargs -r -n1 sudo rpm --import || true

################################################################################
### Install kernel module build dependencies ###################################
################################################################################

KERNEL_PACKAGE="kernel"
if [[ "$(uname -r)" == 6.12.* ]]; then
  KERNEL_PACKAGE="kernel6.12"
fi

if [[ "$(uname -r)" == 6.18.* ]]; then
  KERNEL_PACKAGE="kernel6.18"
fi

sudo dnf -y install \
  "${KERNEL_PACKAGE}-devel" \
  "${KERNEL_PACKAGE}-headers" \
  "${KERNEL_PACKAGE}-modules-extra" \
  "${KERNEL_PACKAGE}-modules-extra-common"

sudo dnf versionlock 'kernel*'

sudo dnf -y install dkms

# To ensure proper functionality, we need to enforce that all three kernel modules are on the same NVIDIA driver version
# so they are compatible with the same userspace components.
# If one of the open module or the grid driver runfile version are older, we use that version for all installations.
function resolve-tree-version() {
  local MAJOR_VERSION="${1}"
  local LATEST_OPEN_DRIVER_VERSION
  local LATEST_GRID_DRIVER_VERSION

  LATEST_OPEN_DRIVER_VERSION=$(dnf repoquery --setopt=*.module_hotfixes=true --latest=1 --queryformat "%{version}" "kmod-nvidia-open-dkms-${MAJOR_VERSION}*")
  if [ -z "${LATEST_OPEN_DRIVER_VERSION}" ]; then
    echo >&2 "ERROR: no kmod-nvidia-open-dkms package found for major version ${MAJOR_VERSION}"
    return 1
  fi

  LATEST_GRID_DRIVER_VERSION=$(aws s3 ls --recursive "s3://${EC2_GRID_DRIVER_S3_BUCKET}/" \
    | grep -Eo "(NVIDIA-Linux-x86_64-)${MAJOR_VERSION}\.[0-9]+\.[0-9]+(-grid-aws\.run)" \
    | cut -d'-' -f4 \
    | sort -V \
    | tail -1 || true)

  if [ -z "${LATEST_GRID_DRIVER_VERSION}" ]; then
    echo >&2 "ERROR: no GRID runfile found for major version ${MAJOR_VERSION} in s3://${EC2_GRID_DRIVER_S3_BUCKET}/"
    return 1
  fi

  if VERCMP_QUIET=true vercmp "${LATEST_OPEN_DRIVER_VERSION}" lteq "${LATEST_GRID_DRIVER_VERSION}"; then
    echo "${LATEST_OPEN_DRIVER_VERSION}"
  else
    echo "${LATEST_GRID_DRIVER_VERSION}"
  fi
}

# Sets up a nvidia driver version tree
function create-driver-tree() {
  local TREE="${1}"
  local MAJOR_VERSION="${2}"

  local DRIVER_VERSION
  DRIVER_VERSION=$(resolve-tree-version "${MAJOR_VERSION}")
  echo "Tree ${TREE}: major version ${MAJOR_VERSION} resolved to ${DRIVER_VERSION}"

  local TREE_DIR="${NVIDIA_TREE_ROOT}/${TREE}"
  sudo mkdir -p "${TREE_DIR}"
  echo "${DRIVER_VERSION}" | sudo tee "${TREE_DIR}/.version" > /dev/null
  # A simple marker to act as conditional for systemd services
  sudo touch "${TREE_DIR}/.tree-${TREE}"
}

# Builds contents of a nvidia driver version tree.
# Stores kernel modules as well as userspace package contents.
function build-driver-tree() {
  local TREE="${1}"
  local TREE_DIR="${NVIDIA_TREE_ROOT}/${TREE}"

  local DRIVER_VERSION
  DRIVER_VERSION=$(cat "${TREE_DIR}/.version")

  extract-version-specific-rpms "${TREE}"
  build-open-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
  build-proprietary-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
  build-grid-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
  install-supported-device-list "${TREE}"
}

################################################################################
### Resolve versions and create the driver trees ###############################
################################################################################

# Runs for every tree first: the rpm download below needs each tree's resolved version.
create-driver-tree lts "${NVIDIA_DRIVER_LTS_VERSION}"
create-driver-tree pb "${NVIDIA_DRIVER_PB_VERSION}"

################################################################################
### NVIDIA version dependent userspace packages  ###############################
################################################################################

# Download all rpms for each version. Partition them into packages shared between both
# versions vs specific to a version. Install the shared packages directly on the host.
download-nvidia-userspace-rpms lts
download-nvidia-userspace-rpms pb
partition-nvidia-userspace-rpms lts pb

install-version-shared-rpms

################################################################################
### Build the driver trees #####################################################
################################################################################

build-driver-tree lts
build-driver-tree pb

################################################################################
### Set up rest of the host ####################################################
################################################################################

# NVLSM
# https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#systems-using-fourth-generation-nvswitches
echo "ib_umad" | sudo tee -a /etc/modules-load.d/ib-umad.conf
sudo dnf -y install \
  libibumad \
  infiniband-diags \
  nvlsm
sudo dnf -y install nvidia-container-toolkit

# %pre scripts of nvidia-persistenced adds a user required to run the persistenced daemon.
create-persistenced-user

################################################################################
### Install boot scripts #######################################################
################################################################################

sudo install -d -m 0755 /etc/eks
sudo install -m 0755 "${WORKING_DIR}/gpu/resolve-nvidia-driver.sh" /etc/eks/resolve-nvidia-driver.sh
sudo install -m 0755 "${WORKING_DIR}/gpu/setup-nvidia.sh" /etc/eks/setup-nvidia.sh

################################################################################
### Install systemd units ######################################################
################################################################################

sudo install -d -m 0755 /etc/systemd/system
sudo install -m 0644 "${WORKING_DIR}/gpu/nvidia-driver-resolve.service" /etc/systemd/system/nvidia-driver-resolve.service
sudo install -m 0644 "${WORKING_DIR}/gpu/nvidia-setup.service" /etc/systemd/system/nvidia-setup.service
sudo install -m 0644 "${WORKING_DIR}/gpu/usr-bin.mount" /etc/systemd/system/usr-bin.mount
sudo install -m 0644 "${WORKING_DIR}/gpu/usr-lib64.mount" /etc/systemd/system/usr-lib64.mount
sudo install -m 0644 "${WORKING_DIR}/gpu/usr-share.mount" /etc/systemd/system/usr-share.mount

# installed but not started at build-time b/c it has an ordering dependency on
# nvidia-persistenced, which is only added at runtime
sudo install -m 0644 "${WORKING_DIR}/gpu/set-nvidia-clocks.service" \
  /etc/systemd/system/set-nvidia-clocks.service

# Overlay upperdir/workdir. Must exist before mount units activate.
sudo mkdir -p /var/lib/eks/nvidia/{bin,lib64,share}/{upper,work}

sudo systemctl enable nvidia-driver-resolve.service \
  nvidia-setup.service \
  usr-bin.mount \
  usr-lib64.mount \
  usr-share.mount
