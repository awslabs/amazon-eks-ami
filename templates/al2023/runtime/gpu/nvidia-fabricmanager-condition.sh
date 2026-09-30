#!/usr/bin/env bash

# ExecCondition for nvidia-fabricmanager.service.
#
# Fabric Manager configures the NVSwitch fabric on hosts that manage one. Everywhere else
# (single-GPU and PCIe-only instances, and GB200/GB300 whose NVSwitches are managed off-host
# by the rack's switch trays) it exits with NV_WARN_NOTHING_TO_DO and leaves a failed unit.
#
#   exit 0  this host manages NVSwitches, or the answer can't be determined: start
#   exit 1  there is nothing to manage: systemd marks the unit skipped rather than failed
#
# systemd treats every exit from 1 to 254 as "skip", so an unexpected error here would
# silently skip Fabric Manager on a host that needs it. errexit and nounset are deliberately
# left off so that only an explicit decision below can return 1, and every path that can't
# reach a decision starts Fabric Manager, same as before this condition existed.

set -o pipefail

readonly NVIDIA_VENDOR_ID="10de"
readonly MELLANOX_VENDOR_ID="15b3"
# the nvidia driver binds every NVIDIA device of this class as an NVSwitch
readonly NVSWITCH_PCI_CLASS_CODE="0680"
# GPUs whose NVSwitches are managed off-host, so the guest never runs Fabric Manager
readonly OFF_HOST_FABRIC_DEVICE_IDS=(
  "2941" # GB200
  "31c2" # GB300
  "31c3" # GB300
)

function start() {
  echo "fabricmanager-condition: ${1}, starting"
  exit 0
}

function skip() {
  echo "fabricmanager-condition: ${1}, skipping"
  exit 1
}

# fields after stripping quotes: domain:slot class vendor device [rev] subvendor subdevice
if ! PCI_DEVICES="$(lspci -D -n -mm | tr -d '"')" || [[ -z "${PCI_DEVICES}" ]]; then
  start "unable to list PCI devices"
fi
readonly PCI_DEVICES

function has_off_host_fabric_gpu() {
  local device_id
  for device_id in "${OFF_HOST_FABRIC_DEVICE_IDS[@]}"; do
    if awk -v vendor="${NVIDIA_VENDOR_ID}" -v device="${device_id}" \
      'tolower($3) == vendor && tolower($4) == device { found = 1 } END { exit !found }' <<< "${PCI_DEVICES}"; then
      return 0
    fi
  done
  return 1
}

# HGX A100/H100/H200: the NVSwitches are PCI devices on the host
function has_nvswitch() {
  awk -v vendor="${NVIDIA_VENDOR_ID}" -v class="${NVSWITCH_PCI_CLASS_CODE}" \
    '$2 == class && tolower($3) == vendor { found = 1 } END { exit !found }' <<< "${PCI_DEVICES}"
}

# NVLink5+ (B200/B300): the NVSwitches are managed through CX7 bridges that carry SW_MNG in
# their VPD. This is the same check nvidia-fabricmanager-start.sh uses to pick its NVLSM path.
function has_nvswitch_management_bridge() {
  local bdf details
  for bdf in $(awk -v vendor="${MELLANOX_VENDOR_ID}" 'tolower($3) == vendor {print $1}' <<< "${PCI_DEVICES}"); do
    if ! details="$(lspci -s "${bdf}" -vvv 2> /dev/null)"; then
      start "unable to read PCI device ${bdf}"
    fi
    if grep -q "SW_MNG" <<< "${details}"; then
      return 0
    fi
  done
  return 1
}

# the off-host check goes first: those systems never need Fabric Manager in the guest, whatever
# the NVSwitch checks below would find
if has_off_host_fabric_gpu; then
  skip "NVSwitch fabric is managed off-host"
fi

if has_nvswitch; then
  start "found NVSwitch devices"
fi

if has_nvswitch_management_bridge; then
  start "found an NVSwitch management bridge"
fi

skip "no NVSwitch fabric on this host"
