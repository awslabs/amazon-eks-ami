#!/usr/bin/env bash

set -x
set -o errexit
set -o pipefail
set -o nounset

NVIDIA_TREE_ROOT="${NVIDIA_TREE_ROOT:-/opt/nvidia}"
LIB_MODULES_DIR="${LIB_MODULES_DIR:-/lib/modules}"
FIRMWARE_DIR="${FIRMWARE_DIR:-/usr/lib/firmware}"

# Hardcoded module list. TODO: introduce a per-flavor manifest at
# ${FLAVOR_SUBTREE}/modules.list, replace these arrays with a
# manifest-driven loop.
readonly REQUIRED_MODULES=(nvidia nvidia-modeset nvidia-drm nvidia-uvm)
# TODO: use a better heuristic than just "optional," e.g. considering if it's required
# on specific hardware
readonly OPTIONAL_MODULES=(nvidia-peermem)

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

VERSION="$(cat "${TREE}/.version")"
readonly VERSION

readonly LOADED_SENTINEL="${TREE}/.loaded"
if [[ ! -f "${LOADED_SENTINEL}" ]]; then
  mkdir -p "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra"
  cp -a --reflink=auto "${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}"/extra/ "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/"
  restorecon -R "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/" 2> /dev/null || true

  readonly FIRMWARE_STAGE="${TREE}/${FIRMWARE_DIR}/nvidia"
  mkdir -p "${FIRMWARE_DIR}/nvidia"
  cp -a --reflink=auto "${FIRMWARE_STAGE}/${VERSION}"/ "${FIRMWARE_DIR}/nvidia/${VERSION}"
  restorecon -R "${FIRMWARE_DIR}/nvidia/${VERSION}" 2> /dev/null || true

  depmod "${KERNEL_VERSION}"

  echo "${KERNEL_VERSION}" > "${LOADED_SENTINEL}"
fi

# modprobes do not persist reboots; invocations should be unguarded
for m in "${REQUIRED_MODULES[@]}"; do
  modprobe "${m}"
done
for m in "${OPTIONAL_MODULES[@]}"; do
  modprobe "${m}" || echo >&2 "load: optional module ${m} did not load"
done

if [[ "${FLAVOR}" == "open" ]]; then
  if modprobe gdrdrv; then
    gdrdrv_major="$(awk '/gdrdrv/{print $1}' /proc/devices)"
    if [[ -n "${gdrdrv_major}" ]]; then
      rm -f /dev/gdrdrv
      mknod -m 666 /dev/gdrdrv c "${gdrdrv_major}" 0
    else
      echo >&2 "load: gdrdrv loaded but no /proc/devices entry; skipping device node"
    fi
  else
    echo >&2 "load: gdrdrv did not load (open flavor, optional)"
  fi
fi

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
