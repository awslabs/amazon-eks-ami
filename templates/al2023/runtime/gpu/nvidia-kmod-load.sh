#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

if ! gpu-ami-util has-nvidia-devices; then
  echo >&2 "no NVIDIA devices are present, not loading kernal module!"
  return 0
fi

NVIDIA_VENDOR_ID="10de"
PCI_CLASS_CODES=(
  "0300" # VGA controller; instance types like g3, g4
  "0302" # 3D controller; instance types like p4, p5
)

INSTANCE_TYPE=$(imds /latest/meta-data/instance-type)

# return the path of the file containing devices supported by the nvidia-open kmod
# fail if the expected file doesn't exist
function nvidia-open-supported-devices-file() {
  local KMOD_MAJOR_VERSION=$(rpmquery kmod-nvidia-latest-dkms --queryformat '%{VERSION}' | cut -d. -f1)
  local SUPPORTED_DEVICE_FILE="/etc/eks/nvidia-open-supported-devices-${KMOD_MAJOR_VERSION}.txt"
  if ! test -f "${SUPPORTED_DEVICE_FILE}"; then
    echo >&2 "Supported device file not found for ${KMOD_MAJOR_VERSION}: ${SUPPORTED_DEVICE_FILE}"
    exit 1
  fi
  echo "${SUPPORTED_DEVICE_FILE}"
}

# determine if the attached nvidia devices are supported by the open-source kernel module
function devices-support-open() {
  local SUPPORTED_DEVICE_FILE=$(nvidia-open-supported-devices-file)
  for PCI_CLASS_CODE in "${PCI_CLASS_CODES[@]}"; do
    for NVIDIA_DEVICE_ID in $(lspci -n -mm -d "${NVIDIA_VENDOR_ID}::${PCI_CLASS_CODE}" | awk '{print $4}' | tr -d '"' | tr '[:lower:]' '[:upper:]'); do
      if ! grep "^0x${NVIDIA_DEVICE_ID}\s" "${SUPPORTED_DEVICE_FILE}"; then
        return 1
      fi
    done
  done
  return 0
}

# load the nvidia kernel module appropriate for the attached devices
MODULE_NAME=""
if devices-support-open; then
  # load the open source kmod
  MODULE_NAME="nvidia-open"
else
  # load the closed source kmod
  MODULE_NAME="nvidia"
fi

function disable-gsp() {
  echo "options nvidia NVreg_EnableGpuFirmware=0" > /etc/modprobe.d/nvidia-disable-gsp.conf
}

# Some g-series instances have an issue with the NVIDIA GPU System Processor (GSP).
# Disabling interactions with the GSP is a temporary workaround, and this is
# only possible on the proprietary kmod.
case "${INSTANCE_TYPE}" in
  g4dn.* | g5.* | g5g.*)
    echo "Disabling GSP for instance type: ${INSTANCE_TYPE}"
    disable-gsp
    echo "Using propreitary module for instance type: ${INSTANCE_TYPE}"
    MODULE_NAME="nvidia"
    ;;

  *)
    echo "No special handling for instance type: ${INSTANCE_TYPE}"
    ;;
esac

kmod-util load "${MODULE_NAME}"
