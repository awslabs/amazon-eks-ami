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

# the proprietary flavor ships its modules as unlinked parts in objects/, which are linked into its
# extra/ on the first boot. the other flavors ship linked modules in extra/
readonly EXTRA_DIR="${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}/extra"
readonly PARTS_DIR="${FLAVOR_SUBTREE}/lib/modules/${KERNEL_VERSION}/objects"

# links each module from the parts its <module>.parts lists, as kbuild does: the parts are combined
# into one object, which is then joined with the module's descriptor. the descriptor refers to the
# module's entry points by name, so the strip in between keeps them.
function link-module-parts() {
  local output_dir=$1
  local module_lds="${LIB_MODULES_DIR}/${KERNEL_VERSION}/build/scripts/module.lds"
  local common_object=()
  local parts_file module_name parts

  # built only by kernels 6.12 and later, where every module is linked with it
  if [[ -f "${PARTS_DIR}/.module-common.o" ]]; then
    common_object=(.module-common.o)
  fi

  for parts_file in "${PARTS_DIR}"/*.parts; do
    module_name=$(basename "${parts_file}" .parts)
    mapfile -t parts < "${parts_file}"
    (
      cd "${PARTS_DIR}"
      ld -r -o "${output_dir}/${module_name}.o" "${parts[@]}"
      strip -g --strip-unneeded --keep-symbol init_module --keep-symbol cleanup_module "${output_dir}/${module_name}.o"
      ld -r -T "${module_lds}" --build-id -o "${output_dir}/${module_name}.ko" \
        "${output_dir}/${module_name}.o" "${module_name}.mod.o" "${common_object[@]}"
    )
    rm -f "${output_dir}/${module_name}.o"
  done
}

VERSION="$(cat "${TREE}/.version")"
readonly VERSION

# copy /etc/ files including modprobe.d and configs. this runs on every boot, and /etc holds
# config files, so -n keeps it from replacing a config a user changed after the first boot.
# TODO: -n is deperecated. Move to --update=none when coreutils 9.3+ is available.
shopt -s dotglob
cp -a -n --reflink=auto "${TREE}"/etc/* /etc/

readonly LOADED_SENTINEL="${TREE}/.loaded"
if [[ ! -f "${LOADED_SENTINEL}" ]]; then
  if [[ "${FLAVOR}" == "proprietary" ]]; then
    mkdir -p "${EXTRA_DIR}"
    link-module-parts "${EXTRA_DIR}"
  fi

  mkdir -p "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra"
  cp -a --reflink=auto "${EXTRA_DIR}/." "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/"
  restorecon -R "${LIB_MODULES_DIR}/${KERNEL_VERSION}/extra/"

  readonly FIRMWARE_STAGE="${TREE}/${FIRMWARE_DIR}/nvidia"
  mkdir -p "${FIRMWARE_DIR}/nvidia/${VERSION}"
  cp -a --reflink=auto "${FIRMWARE_STAGE}/${VERSION}/." "${FIRMWARE_DIR}/nvidia/${VERSION}/"

  depmod "${KERNEL_VERSION}"

  echo "${KERNEL_VERSION}" > "${LOADED_SENTINEL}"
fi

# modprobes do not persist reboots; invocations should be unguarded.
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

readonly DAEMONS_INSTALLED_SENTINEL="${TREE}/.daemons-installed"
if [[ ! -f "${DAEMONS_INSTALLED_SENTINEL}" ]]; then
  # /usr/lib/systemd/system/ is the correct target for package-provided units —
  # /etc/systemd/system/ is reserved for admin overrides.
  install -m 0644 "${TREE}/usr/lib/systemd/system"/*.service /usr/lib/systemd/system/

  DAEMONS=(nvidia-persistenced.service nvidia-fabricmanager.service set-nvidia-clocks.service)
  # gridd is what obtains the vGPU license, and only vGPU devices resolve to the grid flavor.
  # there is nothing to license on passthrough hardware, so it stays disabled there.
  if [[ "${FLAVOR}" == "grid" ]]; then
    DAEMONS+=(nvidia-gridd.service)
  fi

  systemctl daemon-reload
  systemctl enable "${DAEMONS[@]}"
  # let systemd handle service starts in the background b/c they have a declared ordering
  # with this service and so that any potential failures or startup time are not absorbed here
  systemctl start --no-block "${DAEMONS[@]}"

  touch "${DAEMONS_INSTALLED_SENTINEL}"
fi
