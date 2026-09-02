#!/usr/bin/env bash

set -x
set -o errexit
set -o pipefail
set -o nounset

NVIDIA_TREE_ROOT="${NVIDIA_TREE_ROOT:-/opt/nvidia}"
LIB_MODULES_DIR="${LIB_MODULES_DIR:-/lib/modules}"
FIRMWARE_DIR="${FIRMWARE_DIR:-/usr/lib/firmware}"

KERNEL_VERSION="$(uname -r)"
readonly KERNEL_VERSION
readonly TREE="${NVIDIA_TREE_ROOT}/current"

if [[ ! -d "${TREE}" ]]; then
  echo >&2 "load: no ${TREE}"
  exit 1
fi

if ! FLAVOR="$(cat "${TREE}/.driver-flavor")"; then
  echo >&2 "load: no ${TREE}/.driver-flavor"
  exit 1
fi
readonly FLAVOR

readonly FLAVOR_SUBTREE="${TREE}/flavors/${FLAVOR}"
if [[ ! -d "${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}" ]]; then
  echo >&2 "load: no ${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}"
  exit 1
fi

if [[ ! -d "${TREE}/etc" ]]; then
  echo >&2 "setup: no ${TREE}/etc"
  exit 1
fi

VERSION="$(cat "${TREE}/.version")"
readonly VERSION

# copy /etc/ files including modprobe.d and configs
cp -a --reflink=auto "${TREE}/etc/." /etc/
for ENTRY in "${TREE}"/etc/*; do
  restorecon -R "/etc/$(basename "${ENTRY}")" 2> /dev/null || true
done

readonly LOADED_SENTINEL="${TREE}/.loaded"
if [[ ! -f "${LOADED_SENTINEL}" ]]; then
  mkdir -p "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra"
  cp -a --reflink=auto "${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}/extra/." "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/"
  restorecon -R "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/" 2> /dev/null || true

  readonly FIRMWARE_STAGE="${TREE}/${FIRMWARE_DIR}/nvidia"
  mkdir -p "${FIRMWARE_DIR}/nvidia/${VERSION}"
  cp -a --reflink=auto "${FIRMWARE_STAGE}/${VERSION}/." "${FIRMWARE_DIR}/nvidia/${VERSION}/"
  restorecon -R "${FIRMWARE_DIR}/nvidia/${VERSION}" 2> /dev/null || true

  depmod "${KERNEL_VERSION}"

  echo "${KERNEL_VERSION}" > "${LOADED_SENTINEL}"
fi

# modprobes do not persist reboots; invocations should be unguarded.
readonly EXTRA_DIR="${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}/extra"
# the nvidia module is probed first b/c other mods (e.g. gdrdrv) may not
# declare a dependency on it
modprobe nvidia
for ko in "${EXTRA_DIR}"/*.ko*; do
  module_name=$(basename "${ko}")
  module_name="${module_name%%.ko*}"
  case "${module_name}" in
    # nvidia already loaded above; nvidia-peermem binds to Mellanox HCA and fails
    # on Nitro-EFA hosts, functionality is provided thru kernel's DMA buffer instead
    nvidia | nvidia-peermem) continue ;;
  esac
  modprobe "${module_name}"

  # gdrdrv registers a character device but doesn't create the device node itself,
  # so mint /dev/gdrdrv from its /proc/devices allocation
  if [[ "${module_name}" == "gdrdrv" ]]; then
    gdrdrv_major="$(awk '/gdrdrv/{print $1}' /proc/devices)"
    rm -f /dev/gdrdrv
    mknod -m 666 /dev/gdrdrv c "${gdrdrv_major}" 0
  fi
done

# rpm db registration can carry a big time penalty; to optimize first-boot time
# we keep this at the end so it's out of the critical path for functionality
readonly COMMITTED_SENTINEL="${TREE}/.driver-committed"
if [[ ! -f "${COMMITTED_SENTINEL}" ]]; then
  ldconfig
  shopt -s nullglob # the GRID flavor has no specific RPMs to expand to
  readonly RPMS_TO_REGISTER=("${TREE}"/.rpms/*.rpm "${FLAVOR_SUBTREE}"/.rpms/*.rpm)
  shopt -u nullglob
  if ((${#RPMS_TO_REGISTER[@]} > 0)); then
    rpm -i --justdb --noscripts --nodeps --nodigest --nosignature "${RPMS_TO_REGISTER[@]}"
  fi
  {
    echo "version=${VERSION}"
    echo "flavor=${FLAVOR}"
    echo "kernel=${KERNEL_VERSION}"
  } > "${COMMITTED_SENTINEL}"
fi

readonly DAEMONS_INSTALLED_SENTINEL="${TREE}/.daemons-installed"
if [[ ! -f "${DAEMONS_INSTALLED_SENTINEL}" ]]; then
  # /usr/lib/systemd/system/ is the correct target for package-provided units —
  # /etc/systemd/system/ is reserved for admin overrides.
  install -m 0644 "${TREE}/usr/lib/systemd/system"/*.service /usr/lib/systemd/system/

  systemctl daemon-reload
  systemctl enable nvidia-persistenced.service nvidia-fabricmanager.service \
    set-nvidia-clocks.service
  # let systemd handle service starts in the background b/c they have a declared ordering
  # with this service and so that any potential failures or startup time are not absorbed here
  systemctl start --no-block nvidia-persistenced.service nvidia-fabricmanager.service \
    set-nvidia-clocks.service

  touch "${DAEMONS_INSTALLED_SENTINEL}"
fi
