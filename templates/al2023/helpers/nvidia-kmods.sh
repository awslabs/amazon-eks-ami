#!/usr/bin/env bash
#
# Kernel module sources for the driver trees. Each flavor's sources are staged in
# <tree>/flavors/<flavor>/.sources, which build-nvidia-drivers builds the modules from.

# Stage the nvidia open flavor's dkms source rpm
function stage-open-kmod-source() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  stage-kmod-rpm "kmod-nvidia-open-dkms-${DRIVER_VERSION}" "${TREE_DIR}/flavors/open"
}

# Stage the gdrdrv dkms source rpm. Built only with the open nvidia flavor.
function stage-gdrdrv-kmod-source() {
  local TREE_DIR="${1}"

  if [ "${ENABLE_NVIDIA_GDRCOPY_DRIVER}" != "true" ] || [ -z "${NVIDIA_GDRCOPY_DRIVER_VERSION}" ]; then
    return 0
  fi

  stage-kmod-rpm "gdrcopy-kmod-${NVIDIA_GDRCOPY_DRIVER_VERSION}" "${TREE_DIR}/flavors/open"
}

# Stage the nvidia proprietary flavor's dkms source rpm
function stage-proprietary-kmod-source() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  stage-kmod-rpm "kmod-nvidia-latest-dkms-${DRIVER_VERSION}" "${TREE_DIR}/flavors/proprietary"
}

# Stage the GRID runfile the nvidia grid flavor is built from
function stage-grid-kmod-source() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  if [ "${MACHINE}" == "aarch64" ]; then
    echo "No GRID runfile is published for ${MACHINE}, skipping"
    return 0
  fi

  local RUNFILE_NAME="NVIDIA-Linux-x86_64-${DRIVER_VERSION}-grid-aws.run"
  local RUNFILE_KEY
  RUNFILE_KEY=$(aws s3 ls --recursive "s3://${EC2_GRID_DRIVER_S3_BUCKET}/" \
    | grep -F "${RUNFILE_NAME}" \
    | sort -k1,2 \
    | tail -1 \
    | awk '{print $4}' || true)

  if [ -z "${RUNFILE_KEY}" ]; then
    echo >&2 "ERROR: no GRID runfile ${RUNFILE_NAME} in s3://${EC2_GRID_DRIVER_S3_BUCKET}/"
    return 1
  fi

  local DOWNLOAD_DIR="${WORKING_DIR}/nvidia-grid-runfile"
  mkdir -p "${DOWNLOAD_DIR}"
  aws s3 cp "s3://${EC2_GRID_DRIVER_S3_BUCKET%%/*}/${RUNFILE_KEY}" "${DOWNLOAD_DIR}/${RUNFILE_NAME}"

  sudo install -d "${TREE_DIR}/flavors/grid/.sources"
  sudo install -m 0644 "${DOWNLOAD_DIR}/${RUNFILE_NAME}" "${TREE_DIR}/flavors/grid/.sources/"
  sudo rm -rf "${DOWNLOAD_DIR}"
}

# Download a kmod source rpm into a flavor's .sources directory, for build-nvidia-drivers to
# build from and the boot-time commit phase to register in the rpm database.
function stage-kmod-rpm() {
  local SOURCE_PACKAGE="${1}"
  local FLAVOR_SUBTREE="${2}"
  local DOWNLOAD_DIR="${WORKING_DIR}/nvidia-kmod-rpms"

  mkdir -p "${DOWNLOAD_DIR}"
  sudo dnf download --setopt=*.module_hotfixes=true --destdir="${DOWNLOAD_DIR}" "${SOURCE_PACKAGE}"

  # dnf download skips signature checks, so verify before staging.
  rpm -K "${DOWNLOAD_DIR}"/*.rpm

  sudo install -d "${FLAVOR_SUBTREE}/.sources"
  sudo install -m 0644 "${DOWNLOAD_DIR}"/*.rpm "${FLAVOR_SUBTREE}/.sources/"
  sudo rm -rf "${DOWNLOAD_DIR}"
}
