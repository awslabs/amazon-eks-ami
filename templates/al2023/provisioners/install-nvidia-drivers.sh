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

################################################################################
### Resolve versions and create the driver trees ###############################
################################################################################

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

function build-driver-tree() {
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

  build-open-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
  build-proprietary-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
  build-grid-kmods "${TREE_DIR}" "${DRIVER_VERSION}"
}

build-driver-tree lts "${NVIDIA_DRIVER_LTS_VERSION}"
build-driver-tree pb "${NVIDIA_DRIVER_PB_VERSION}"
