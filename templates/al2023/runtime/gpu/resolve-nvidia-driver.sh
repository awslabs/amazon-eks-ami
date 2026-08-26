#!/usr/bin/env bash

set -x
set -o errexit
set -o pipefail
set -o nounset

NVIDIA_TREE_ROOT="${NVIDIA_TREE_ROOT:-/opt/nvidia}"
EKS_CONFIG_DIR="${EKS_CONFIG_DIR:-/etc/eks}"
MODPROBE_D_DIR="${MODPROBE_D_DIR:-/etc/modprobe.d}"
DMI_PRODUCT_NAME_PATH="${DMI_PRODUCT_NAME_PATH:-/sys/devices/virtual/dmi/id/product_name}"

readonly NVIDIA_VENDOR_ID="10de"
readonly PCI_CLASS_CODES=(
  "0300" # VGA controller; instance types like g3, g4
  "0302" # 3D controller; instance types like p4, p5
)

# NVIDIA vGPU (GRID) device:subsystem tuples. Format: "DEVICE:SUBDEVICE" (lowercase, no 0x prefix).
readonly GRID_REQUIRED_SUBDEVICES=(
  "27b8:1733" # L4:L4-3Q
  "27b8:1735" # L4:L4-6Q
  "27b8:1737" # L4:L4-12Q
)

# Return 0 iff every attached NVIDIA GPU's device id is present in the given
# supported-devices file. Returns 1 if any device id is absent from the file.
function devices_supported_by() {
  local support_file="${1}"
  if [[ ! -f "${support_file}" ]]; then
    echo >&2 "resolve: supported-devices file not found: ${support_file}"
    exit 1
  fi
  local pci_class_code nvidia_device_id
  for pci_class_code in "${PCI_CLASS_CODES[@]}"; do
    for nvidia_device_id in $(lspci -n -mm -d "${NVIDIA_VENDOR_ID}::${pci_class_code}" | awk '{print $4}' | tr -d '"' | tr '[:lower:]' '[:upper:]'); do
      if ! grep "^0x${nvidia_device_id}\s" "${support_file}"; then
        return 1
      fi
    done
  done
  return 0
}

function device-requires-grid() {
  local nvidia_grid_subdevice nvidia_subdevice
  for nvidia_grid_subdevice in "${GRID_REQUIRED_SUBDEVICES[@]}"; do
    for nvidia_subdevice in $(lspci -n -mm -d "${NVIDIA_VENDOR_ID}:" | awk '{print $4":"$7}' | tr -d '"'); do
      if [[ "${nvidia_grid_subdevice}" == "${nvidia_subdevice}" ]]; then
        return 0
      fi
    done
  done
  return 1
}

function has_nvidia_gpu() {
  local pci_class_code
  for pci_class_code in "${PCI_CLASS_CODES[@]}"; do
    if lspci -n -mm -d "${NVIDIA_VENDOR_ID}::${pci_class_code}" | grep -q .; then
      return 0
    fi
  done
  return 1
}

function main() {
  local instance_type tree flavor lts_major pb_major tree_path current_tree_path

  if ! has_nvidia_gpu; then
    echo "resolve: no NVIDIA GPU attached, doing nothing"
    return 0
  fi

  if ! instance_type=$(cat "${DMI_PRODUCT_NAME_PATH}"); then
    echo "resolve: failed to read instance_type from ${DMI_PRODUCT_NAME_PATH}"
    exit 1
  fi

  if ! lts_major="$(cat "${NVIDIA_TREE_ROOT}/lts/.version" 2> /dev/null | cut -d. -f1)"; then
    lts_major=""
  fi
  if ! pb_major="$(cat "${NVIDIA_TREE_ROOT}/pb/.version" 2> /dev/null | cut -d. -f1)"; then
    pb_major=""
  fi

  # LTS open -> PB open -> LTS proprietary. GRID override applied, if required.
  # SAFETY: choosing LTS/PB open is trivially safe, the NVIDIA open supported devices stipulates they should work.
  # defaulting to LTS proprietary assumes that any device supported by neither the LTS nor PB should be supported
  # by the proprietary. this should be true since GRID-required devices are shown as open supported, and NVIDIA
  # favors open module support for newer GPUs, with older device support sometimes dropped, and PB should always >= LTS
  if [[ -n "${lts_major}" ]] \
    && devices_supported_by "${EKS_CONFIG_DIR}/nvidia-open-supported-devices-${lts_major}.txt"; then
    tree="lts"
    flavor="open"
  elif [[ -n "${pb_major}" ]] \
    && devices_supported_by "${EKS_CONFIG_DIR}/nvidia-open-supported-devices-${pb_major}.txt"; then
    tree="pb"
    flavor="open"
  else
    tree="lts"
    flavor="proprietary"
  fi

  if device-requires-grid; then
    flavor="grid"
  fi

  # older g-series instance types required GSP to be disabled, which can only be done on the
  # proprietary driver
  case "${instance_type}" in
    g4dn.* | g5.* | g5g.*)
      tree="lts"
      flavor="proprietary"
      printf 'options nvidia NVreg_EnableGpuFirmware=0\n' \
        > "${MODPROBE_D_DIR}/nvidia-disable-gsp.conf"
      ;;
  esac

  tree_path="${NVIDIA_TREE_ROOT}/${tree}"
  if [[ ! -d "${tree_path}" || ! -f "${tree_path}/.tree-${tree}" ]]; then
    echo >&2 "resolve: no ${tree} tree at ${tree_path} (missing directory or .tree-${tree} marker)"
    exit 1
  fi

  current_tree_path="${NVIDIA_TREE_ROOT}/current"
  if ! ln -sfn "${tree_path}" "${current_tree_path}"; then
    echo >&2 "resolve: ln -sfn ${tree_path} ${current_tree_path} failed"
    exit 1
  fi

  printf 'options nvidia NVreg_CoherentGPUMemoryMode=driver\n' \
    > "${MODPROBE_D_DIR}/40-eks-nvidia-openrm.conf"

  # commit the driver flavor to a state file at the end so that it can be used as a sentinel
  # for systemd to skip running the service on subsequent boots
  printf '%s\n' "${flavor}" > "${current_tree_path}/.driver-flavor"
}

main "$@"
