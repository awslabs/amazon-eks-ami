#!/usr/bin/env bash
#
# Per-flavor builders for one driver tree's kernel modules, each harvesting into
# <tree>/flavors/<flavor>/lib/modules/<kernel>/.

KERNEL_RELEASE="$(uname -r)"
readonly KERNEL_RELEASE

ARCH="$(uname -m)"
readonly ARCH

# Build and harvests nvidia open flavor kernel modules
function build-open-kmods() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  echo "Building open kernel modules for NVIDIA ${DRIVER_VERSION}"
  extract-kmod-source "kmod-nvidia-open-dkms-${DRIVER_VERSION}" "${TREE_DIR}"
  sudo dkms add -m nvidia -v "${DRIVER_VERSION}"
  sudo dkms build -m nvidia -v "${DRIVER_VERSION}"
  harvest-dkms-modules nvidia "${DRIVER_VERSION}" "${TREE_DIR}/flavors/open"

  # Built here, while this version's nvidia source is the only one in /usr/src.
  build-gdrdrv "${TREE_DIR}" "${DRIVER_VERSION}"

  sudo dkms remove -m nvidia -v "${DRIVER_VERSION}" --all
  sudo rm -rf "/usr/src/nvidia-${DRIVER_VERSION}"
}

# Build and harvests nvidia proprietary flavor kernel modules
function build-proprietary-kmods() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  echo "Building proprietary kernel modules for NVIDIA ${DRIVER_VERSION}"
  extract-kmod-source "kmod-nvidia-latest-dkms-${DRIVER_VERSION}" "${TREE_DIR}"
  sudo dkms add -m nvidia -v "${DRIVER_VERSION}"
  sudo dkms build -m nvidia -v "${DRIVER_VERSION}"
  harvest-dkms-modules nvidia "${DRIVER_VERSION}" "${TREE_DIR}/flavors/proprietary"

  sudo dkms remove -m nvidia -v "${DRIVER_VERSION}" --all
  sudo rm -rf "/usr/src/nvidia-${DRIVER_VERSION}"
}

# Build and harvests gdrdrv kernel modules. Built only with the open nvidia flavor
function build-gdrdrv() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  if [ "${ENABLE_NVIDIA_GDRCOPY_DRIVER}" != "true" ] || [ -z "${NVIDIA_GDRCOPY_DRIVER_VERSION}" ]; then
    return 0
  fi

  local GDRCOPY_VERSION="${NVIDIA_GDRCOPY_DRIVER_VERSION}"

  echo "Building gdrdrv ${GDRCOPY_VERSION} against NVIDIA ${DRIVER_VERSION}"
  extract-kmod-source "gdrcopy-kmod-${GDRCOPY_VERSION}" "${TREE_DIR}"
  sudo dkms add -m gdrdrv -v "${GDRCOPY_VERSION}"
  sudo dkms build -m gdrdrv -v "${GDRCOPY_VERSION}"
  harvest-dkms-modules gdrdrv "${GDRCOPY_VERSION}" "${TREE_DIR}/flavors/open"

  sudo dkms remove -m gdrdrv -v "${GDRCOPY_VERSION}" --all
  sudo rm -rf "/usr/src/gdrdrv-${GDRCOPY_VERSION}"
}

# Build and harvest nvidia grid flavor kernel modules
function build-grid-kmods() {
  local TREE_DIR="${1}"
  local DRIVER_VERSION="${2}"

  if [ "${ARCH}" == "aarch64" ]; then
    echo "No GRID runfile is published for ${ARCH}, skipping"
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

  local GRID_DIR="${WORKING_DIR}/nvidia-grid-${DRIVER_VERSION}"
  local RUNFILE_PATH="${GRID_DIR}/${RUNFILE_NAME}"
  local KERNEL_OPEN_DIR="${GRID_DIR}/source/kernel-open"
  mkdir -p "${GRID_DIR}"

  echo "Building GRID kernel modules for NVIDIA ${DRIVER_VERSION}"
  aws s3 cp "s3://${EC2_GRID_DRIVER_S3_BUCKET%%/*}/${RUNFILE_KEY}" "${RUNFILE_PATH}"
  chmod +x "${RUNFILE_PATH}"
  "${RUNFILE_PATH}" --extract-only --target "${GRID_DIR}/source"

  make -C "${KERNEL_OPEN_DIR}" \
    -j"$(nproc)" \
    SYSSRC="/lib/modules/${KERNEL_RELEASE}/build" \
    modules

  # Harvest the modules to the tree
  local DEST_DIR="${TREE_DIR}/flavors/grid/lib/modules/${KERNEL_RELEASE}/extra"
  local MODULE_PATH
  sudo install -d "${DEST_DIR}"
  for MODULE_PATH in "${KERNEL_OPEN_DIR}"/*.ko; do
    strip -g --strip-unneeded "${MODULE_PATH}"
    sudo install -m 0644 "${MODULE_PATH}" "${DEST_DIR}/"
  done

  sudo rm -rf "${GRID_DIR}"
}

# Download a kmod source rpm and unpack it
function extract-kmod-source() {
  local SOURCE_PACKAGE="${1}"
  local TREE_DIR="${2}"
  local DOWNLOAD_DIR="${WORKING_DIR}/nvidia-kmod-rpms"

  mkdir -p "${DOWNLOAD_DIR}"
  sudo dnf download --setopt=*.module_hotfixes=true --destdir="${DOWNLOAD_DIR}" "${SOURCE_PACKAGE}"

  # dnf download skips signature checks, so verify before unpacking.
  rpm -K "${DOWNLOAD_DIR}"/*.rpm
  rpm2cpio "${DOWNLOAD_DIR}"/*.rpm | (cd / && sudo cpio -idmu --quiet)

  # Save the RPM files for rpmdb registration later.
  sudo install -d "${TREE_DIR}/.rpms"
  sudo mv "${DOWNLOAD_DIR}"/*.rpm "${TREE_DIR}/.rpms/"
  sudo rm -rf "${DOWNLOAD_DIR}"
}

# Copy the modules a dkms.conf declares out of the dkms build tree and into a flavor
# All dkms modules end up in /lib/modules/${KERNEL_RELEASE}/extra for AL2023
# https://man.archlinux.org/man/extra/dkms/dkms.8.en#DEST_MODULE_LOCATION___=
function harvest-dkms-modules() {
  local PACKAGE_NAME="${1}"
  local PACKAGE_VERSION="${2}"
  local DEST_DIR="${3}/lib/modules/${KERNEL_RELEASE}/extra"
  local DKMS_MODULE_DIR="/var/lib/dkms/${PACKAGE_NAME}/${PACKAGE_VERSION}/${KERNEL_RELEASE}/${ARCH}/module"

  local DECLARED_MODULES
  DECLARED_MODULES=$(dkms-declared-modules "${PACKAGE_NAME}" "${PACKAGE_VERSION}")
  local MODULE_NAMES
  mapfile -t MODULE_NAMES <<< "${DECLARED_MODULES}"

  sudo install -d "${DEST_DIR}"
  local MODULE_NAME
  for MODULE_NAME in "${MODULE_NAMES[@]}"; do
    # The suffix varies with the kernel's module compression.
    if ! compgen -G "${DKMS_MODULE_DIR}/${MODULE_NAME}.ko*" > /dev/null; then
      echo >&2 "ERROR: ${PACKAGE_NAME} declares ${MODULE_NAME}, missing from ${DKMS_MODULE_DIR}"
      return 1
    fi
    sudo install -m 0644 "${DKMS_MODULE_DIR}/${MODULE_NAME}".ko* "${DEST_DIR}/"
  done
}

# Print the module names a dkms.conf declares.
# https://man.archlinux.org/man/extra/dkms/dkms.8.en#BUILT_MODULE_NAME___=
function dkms-declared-modules() {
  local PACKAGE_NAME="${1}"
  local PACKAGE_VERSION="${2}"
  local PACKAGE_DKMS_CONF="/usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}/dkms.conf"

  (
    # Exported for the conf's MAKE line, which expands them at source time.
    export kernelver="${KERNEL_RELEASE}"
    export dkms_tree="/var/lib/dkms"
    declare -a BUILT_MODULE_NAME=()
    # shellcheck disable=SC1090
    if ! source "${PACKAGE_DKMS_CONF}" > /dev/null; then
      echo >&2 "ERROR: cannot read ${PACKAGE_DKMS_CONF}"
      exit 1
    fi
    if [ "${#BUILT_MODULE_NAME[@]}" -eq 0 ]; then
      echo >&2 "ERROR: ${PACKAGE_DKMS_CONF} declares no modules"
      exit 1
    fi
    printf '%s\n' "${BUILT_MODULE_NAME[@]}"
  )
}
