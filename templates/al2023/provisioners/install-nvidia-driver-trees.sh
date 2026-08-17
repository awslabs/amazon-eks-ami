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

readonly NVIDIA_TREES=(lts pb)
declare -A NVIDIA_TREE_MAJOR=(
  [lts]="${NVIDIA_DRIVER_LTS_VERSION}"
  [pb]="${NVIDIA_DRIVER_PB_VERSION}"
)
declare -A NVIDIA_TREE_VERSION=()

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

################################################################################
### Resolve versions and create the driver trees ###############################
################################################################################

# To ensure proper functionality, we need to enforce that all three kernel modules are on the same NVIDIA driver version
# so they are compatible with the same userspace components.
# If one of the open module or the grid driver runfile version are older, we use that version for all installations.
function resolve-tree-version() {
  local MAJOR="${1}"
  local LATEST_OPEN_DRIVER_VERSION
  local LATEST_GRID_DRIVER_VERSION

  LATEST_OPEN_DRIVER_VERSION=$(dnf repoquery --setopt=*.module_hotfixes=true --latest=1 --queryformat "%{version}" "kmod-nvidia-open-dkms-${MAJOR}*")
  if [ -z "${LATEST_OPEN_DRIVER_VERSION}" ]; then
    echo >&2 "ERROR: no kmod-nvidia-open-dkms package found for major version ${MAJOR}"
    return 1
  fi

  LATEST_GRID_DRIVER_VERSION=$(aws s3 ls --recursive "s3://${EC2_GRID_DRIVER_S3_BUCKET}/" \
    | grep -Eo "(NVIDIA-Linux-x86_64-)${MAJOR}\.[0-9]+\.[0-9]+(-grid-aws\.run)" \
    | cut -d'-' -f4 \
    | sort -V \
    | tail -1 || true)

  if [ -z "${LATEST_GRID_DRIVER_VERSION}" ]; then
    echo >&2 "ERROR: no GRID runfile found for major version ${MAJOR} in s3://${EC2_GRID_DRIVER_S3_BUCKET}/"
    return 1
  fi

  if vercmp "${LATEST_OPEN_DRIVER_VERSION}" lteq "${LATEST_GRID_DRIVER_VERSION}"; then
    echo "${LATEST_OPEN_DRIVER_VERSION}"
  else
    echo "${LATEST_GRID_DRIVER_VERSION}"
  fi
}

for TREE in "${NVIDIA_TREES[@]}"; do
  MAJOR="${NVIDIA_TREE_MAJOR[${TREE}]}"
  NVIDIA_TREE_VERSION[${TREE}]=$(resolve-tree-version "${MAJOR}")
  echo "Tree ${TREE}: major version ${MAJOR} resolved to ${NVIDIA_TREE_VERSION[${TREE}]}"

  TREE_DIR="${NVIDIA_TREE_ROOT}/${TREE}"
  sudo mkdir -p "${TREE_DIR}"
  echo "${NVIDIA_TREE_VERSION[${TREE}]}" | sudo tee "${TREE_DIR}/.version" > /dev/null
  # A simple marker to act as conditional for systemd services
  sudo touch "${TREE_DIR}/.tree-${TREE}"
done
