#!/usr/bin/env bash
#
# Userspace for the driver trees. Packages identical across driver versions are installed on
# the host once. The rest go into their own tree, since the host cannot hold two versions of
# the same package.

readonly NVIDIA_USERSPACE_RPM_DIR="${WORKING_DIR}/nvidia-userspace-rpms"
readonly NVIDIA_VERSION_SHARED_RPM_DIR="${NVIDIA_USERSPACE_RPM_DIR}/version-shared"

readonly NVIDIA_USERSPACE_PACKAGES=(
  libnvidia-fbc
  nvidia-driver
  nvidia-driver-cuda
  nvidia-fabricmanager
  nvidia-libXNVCtrl-devel
  nvidia-persistenced
  nvidia-settings
  nvidia-xconfig
  xorg-x11-nvidia
)

# Download one tree's full set of userspace rpms without installing any of them.
function download-nvidia-userspace-rpms() {
  local TREE="${1}"
  local RPM_LIST="${NVIDIA_USERSPACE_RPM_DIR}/${TREE}"

  local DRIVER_VERSION
  DRIVER_VERSION=$(cat "${NVIDIA_TREE_ROOT}/${TREE}/.version")

  local VERSIONED_PACKAGES=()
  local PACKAGE
  for PACKAGE in "${NVIDIA_USERSPACE_PACKAGES[@]}"; do
    VERSIONED_PACKAGES+=("${PACKAGE}-${DRIVER_VERSION}")
  done

  echo "Downloading the NVIDIA ${DRIVER_VERSION} userspace rpms for tree ${TREE}"
  mkdir -p "${RPM_LIST}"
  sudo dnf install -y --downloadonly --destdir="${RPM_LIST}" \
    --setopt=*.module_hotfixes=true \
    "${VERSIONED_PACKAGES[@]}"

  # The version-specific rpms are extracted rather than installed, so no transaction ever
  # verifies them.
  rpm -K "${RPM_LIST}"/*.rpm
}

# Identifies packages shared between 2 trees and moves them to a common directory
function partition-nvidia-userspace-rpms() {
  if [ "${#}" -ne 2 ]; then
    echo >&2 "ERROR: partition-nvidia-userspace-rpms compares exactly two rpm lists, got ${#}"
    return 1
  fi

  local RPM_LIST_1="${NVIDIA_USERSPACE_RPM_DIR}/${1}"
  local RPM_LIST_2="${NVIDIA_USERSPACE_RPM_DIR}/${2}"
  local RPM RPM_FILENAME MATCHING_RPM
  local VERSION_SHARED_COUNT=0

  mkdir -p "${NVIDIA_VERSION_SHARED_RPM_DIR}"
  for RPM in "${RPM_LIST_1}"/*.rpm; do
    RPM_FILENAME=$(basename "${RPM}")
    MATCHING_RPM="${RPM_LIST_2}/${RPM_FILENAME}"
    [ -e "${MATCHING_RPM}" ] || continue

    sudo mv "${RPM}" "${NVIDIA_VERSION_SHARED_RPM_DIR}/"
    sudo rm -f "${MATCHING_RPM}"
    VERSION_SHARED_COUNT=$((VERSION_SHARED_COUNT + 1))
  done

  echo "Userspace rpms: ${VERSION_SHARED_COUNT} shared between ${1} and ${2}"
}

# Install the version-shared rpms on the host normally, so their scriptlets run and the rpm
# database is populated without emulation.
function install-version-shared-rpms() {
  if ! compgen -G "${NVIDIA_VERSION_SHARED_RPM_DIR}/*.rpm" > /dev/null; then
    echo >&2 "ERROR: ${NVIDIA_VERSION_SHARED_RPM_DIR} is empty, the trees have no rpms in common"
    return 1
  fi

  local VERSION_SHARED_RPMS=("${NVIDIA_VERSION_SHARED_RPM_DIR}"/*.rpm)

  echo "Installing ${#VERSION_SHARED_RPMS[@]} version-shared userspace packages on the host"
  sudo dnf install -y --setopt=keepcache=1 --setopt=*.module_hotfixes=true "${VERSION_SHARED_RPMS[@]}"

  sudo rm -rf "${NVIDIA_VERSION_SHARED_RPM_DIR}"
}

# Extract contents of version specific packages into the tree
function extract-version-specific-rpms() {
  local TREE="${1}"
  local TREE_DIR="${NVIDIA_TREE_ROOT}/${TREE}"
  local RPM_LIST="${NVIDIA_USERSPACE_RPM_DIR}/${TREE}"
  local RPM

  if ! compgen -G "${RPM_LIST}/*.rpm" > /dev/null; then
    echo >&2 "ERROR: nothing version-specific for tree ${TREE}, check that the trees resolved to different versions"
    return 1
  fi

  local VERSION_SPECIFIC_RPMS=("${RPM_LIST}"/*.rpm)
  echo "Extracting ${#VERSION_SPECIFIC_RPMS[@]} version-specific packages into ${TREE_DIR}:"

  # Staged whole so the boot-time commit phase can register them in the rpm database.
  sudo install -d "${TREE_DIR}/.rpms"
  for RPM in "${VERSION_SPECIFIC_RPMS[@]}"; do
    echo "  $(basename "${RPM}")"
    rpm2cpio "${RPM}" | (cd "${TREE_DIR}" && sudo cpio -idmu --quiet)
    sudo install -m 0644 "${RPM}" "${TREE_DIR}/.rpms/"
  done

  sudo rm -rf "${RPM_LIST}"
}

# https://github.com/NVIDIA/yum-packaging-nvidia-persistenced/blob/fedora/nvidia-persistenced.spec
function create-persistenced-user() {
  if ! getent group nvidia-persistenced > /dev/null; then
    sudo groupadd -r nvidia-persistenced
  fi
  if ! getent passwd nvidia-persistenced > /dev/null; then
    sudo useradd -r -g nvidia-persistenced -d /var/run/nvidia-persistenced -s /sbin/nologin \
      -c "NVIDIA Persistence Daemon" nvidia-persistenced
  fi
}

# Supported device list per major version.
# Used to resolve target version at boot
function install-supported-device-list() {
  local TREE="${1}"

  local DRIVER_VERSION
  DRIVER_VERSION=$(cat "${NVIDIA_TREE_ROOT}/${TREE}/.version")
  local MAJOR_VERSION="${DRIVER_VERSION%%.*}"
  local DEVICE_LIST="${WORKING_DIR}/gpu/nvidia-open-supported-devices-${MAJOR_VERSION}.txt"

  if [ ! -f "${DEVICE_LIST}" ]; then
    echo >&2 "ERROR: no supported-devices list for major version ${MAJOR_VERSION}, found:"
    ls >&2 "${WORKING_DIR}/gpu/"nvidia-open-supported-devices-*.txt
    return 1
  fi

  sudo install -m 0644 "${DEVICE_LIST}" /etc/eks/
}
