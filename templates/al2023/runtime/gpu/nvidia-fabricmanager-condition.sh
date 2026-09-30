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

# PCI vendor IDs, as assigned in the PCI ID database that lspci uses to name devices
# (/usr/share/hwdata/pci.ids from the hwdata package, or https://pci-ids.ucw.cz):
#   10de  NVIDIA Corporation
#   15b3  Mellanox Technologies (now NVIDIA networking; the ConnectX NICs and CX7 bridges)
readonly NVIDIA_VENDOR_ID="10de"
readonly MELLANOX_VENDOR_ID="15b3"
# PCI class 0x0680 is "Bridge: other" (PCI_CLASS_BRIDGE_OTHER). The nvidia driver claims every
# NVIDIA device of this class as an NVSwitch, see nvswitch_pci_table in
# kernel-open/nvidia/linux_nvswitch.c and the define in kernel-open/nvidia/nv-pci-table.c of
# https://github.com/NVIDIA/open-gpu-kernel-modules
readonly NVSWITCH_PCI_CLASS_CODE="0680"
# GPUs whose NVSwitches are managed off-host by the rack's switch trays, so the guest never runs
# Fabric Manager. Device IDs are from NVIDIA's supported-gpus.json, as captured in the
# nvidia-open-supported-devices-*.txt lists alongside this script.
readonly OFF_HOST_FABRIC_DEVICE_IDS=(
  "2941" # GB200 (570 and later)
  "31c2" # GB300 (580 and later)
  "31c3" # GB300 (595 and later)
)

function start() {
  echo "fabricmanager-condition: ${1}, starting"
  exit 0
}

function skip() {
  echo "fabricmanager-condition: ${1}, skipping"
  exit 1
}

# One line per PCI device, from `lspci -D -n -mm` with the quotes stripped. For example, three of
# the lines on a p4d.24xlarge:
#
#   0000:10:1c.0 0302 10de 20b0 -ra1 10de 134f    <- an A100 GPU
#   0000:80:1a.0 0680 10de 1af1 -ra1 10de 13b8    <- an NVSwitch
#   0000:00:04.0 0108 1d0f 8061 -p02 1d0f 0000    <- the EBS NVMe controller (no -r, has -p)
#
# so awk sees  $1 = domain:bus:slot.function   $2 = class   $3 = vendor   $4 = device.
# The optional -r (revision) and -p (prog-if) tokens, and any empty "" fields, only appear after
# $4, so the fields read below never shift.
if ! PCI_DEVICES="$(lspci -D -n -mm | tr -d '"')" || [[ -z "${PCI_DEVICES}" ]]; then
  start "unable to list PCI devices"
fi
readonly PCI_DEVICES

# The awk checks below all follow one pattern: `{ found = 1 }` runs for each matching line, and
# `END { exit !found }` makes awk exit 0 if any line matched and 1 if none did, so each check can
# be used directly as an `if` condition. tolower() is defensive: lspci prints lowercase hex, but
# the nvidia-open-supported-devices-*.txt lists these IDs come from use uppercase (0x31C2).

function has_off_host_fabric_gpu() {
  local device_id
  for device_id in "${OFF_HOST_FABRIC_DEVICE_IDS[@]}"; do
    # match an NVIDIA device with this device ID, e.g. for 2941 (GB200):
    #   0008:06:00.0 0302 10de 2941 -ra1 10de 2046    <- match
    #   0000:00:1e.0 0302 10de 1eb8 -ra1 10de 12a2    <- no match (a T4)
    if awk -v vendor="${NVIDIA_VENDOR_ID}" -v device="${device_id}" \
      'tolower($3) == vendor && tolower($4) == device { found = 1 } END { exit !found }' <<< "${PCI_DEVICES}"; then
      return 0
    fi
  done
  return 1
}

# HGX A100/H100/H200: the NVSwitches are PCI devices on the host
function has_nvswitch() {
  # match any NVIDIA device of class 0680, whatever its device ID:
  #   0000:80:1a.0 0680 10de 1af1 -ra1 10de 13b8    <- match (an A100 NVSwitch)
  #   0000:10:1c.0 0302 10de 20b0 -ra1 10de 134f    <- no match (a GPU, class 0302)
  awk -v vendor="${NVIDIA_VENDOR_ID}" -v class="${NVSWITCH_PCI_CLASS_CODE}" \
    '$2 == class && tolower($3) == vendor { found = 1 } END { exit !found }' <<< "${PCI_DEVICES}"
}

# NVLink5+ (B200/B300): the NVSwitches aren't PCI devices on the host. They're managed through
# CX7 bridges whose VPD (Vital Product Data) carries the SW_MNG keyword. The keyword and the
# lspci -vvv check both come from /usr/bin/nvidia-fabricmanager-start.sh in NVIDIA's
# nvidia-fabricmanager package, which uses them to choose its NVLSM path.
function has_nvswitch_management_bridge() {
  local bdf details
  # print the address ($1) of every Mellanox device. For example, for a ConnectX-7 line like
  #   0000:73:00.0 0207 15b3 1021 15b3 0087    <- class 0207 (Infiniband), device 1021 (CX7)
  # it prints 0000:73:00.0
  # then read each one's full details, which is where lspci shows the VPD
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
