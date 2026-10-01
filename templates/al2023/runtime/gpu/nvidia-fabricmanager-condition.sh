#!/usr/bin/env bash

# ExecCondition for nvidia-fabricmanager.service.
#
# Fabric Manager configures the NVSwitch fabric on hosts that manage one. Everywhere else
# (single-GPU and PCIe-only instances, and systems like GB200/GB300 NVL72 whose NVSwitches sit
# off-host in the rack's switch trays) it exits with NV_WARN_NOTHING_TO_DO and leaves a failed unit.
#
#   exit 0  this host has an NVSwitch, or the answer can't be determined: start
#   exit 1  there is nothing to manage: systemd marks the unit skipped rather than failed
#
# A false negative (skipping where Fabric Manager is needed) is far worse than a false positive
# (one failed unit, the behavior before this condition existed), so every check below only
# looks for evidence to start, and anything inconclusive starts.
#
# systemd treats every exit from 1 to 254 as "skip", so an unexpected error here would
# silently skip Fabric Manager on a host that needs it. errexit and nounset are deliberately
# left off so that only the explicit decision at the end can return 1.

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
# When the nvidia driver's NVSwitch probe claims a device, it adds an entry for it here
# (nvswitch_procfs_device_add in kernel-open/nvidia/procfs_nvswitch.c, same repo). It's the
# check NVIDIA's gpu-driver-container uses to decide whether to start Fabric Manager.
# Overridable only so validate.sh can exercise this check.
readonly NVSWITCH_PROCFS_DEVICES="${NVSWITCH_PROCFS_DEVICES:-/proc/driver/nvidia-nvswitch/devices}"

function start() {
  echo "fabricmanager-condition: ${1}, starting"
  exit 0
}

function skip() {
  echo "fabricmanager-condition: ${1}, skipping"
  exit 1
}

# HGX A100/H100/H200: the nvidia driver has registered at least one NVSwitch. nvidia-setup.service
# loads the driver and is ordered before Fabric Manager, so on these hosts the directory should
# be populated by the time this runs; the lspci check below covers the case where it isn't.
if [[ -n "$(ls -A "${NVSWITCH_PROCFS_DEVICES}" 2> /dev/null)" ]]; then
  start "found NVSwitch devices registered by the nvidia driver"
fi

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
# If lspci fails (pipefail catches that even though tr succeeds) or prints nothing, which can't
# happen on a working instance, there's no data to decide from. Every check below would then
# find nothing and fall through to skip, so bail out first and fail open. The two ways to be
# wrong are not equal:
#   - wrongly starting on a host with no NVSwitch fabric costs one failed unit, which is exactly
#     the behavior before this condition existed
#   - wrongly skipping on a host that has one leaves the NVSwitch fabric unconfigured. Per NVIDIA's
#     Fabric Manager user guide, on HGX A100 (p4d) CUDA initialization then fails with
#     cudaErrorSystemNotReady, and on HGX H100 and later (p5, p6-b200) the GPUs can't register
#     with the fabric and lose NVLink peer-to-peer
#     https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html
if ! PCI_DEVICES="$(lspci -D -n -mm | tr -d '"')" || [[ -z "${PCI_DEVICES}" ]]; then
  start "unable to list PCI devices"
fi
readonly PCI_DEVICES

# The awk checks below follow one pattern: `{ found = 1 }` runs for each matching line, and
# `END { exit !found }` makes awk exit 0 if any line matched and 1 if none did, so each check can
# be used directly as an `if` condition. tolower() is defensive: lspci prints lowercase hex.

# HGX A100/H100/H200, independent of whether the driver has loaded yet: the NVSwitches are PCI
# devices on the host
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

if has_nvswitch; then
  start "found NVSwitch devices"
fi

if has_nvswitch_management_bridge; then
  start "found an NVSwitch management bridge"
fi

skip "no NVSwitch fabric on this host"
