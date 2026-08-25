#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

validate_file_nonexists() {
  local file_blob=$1
  for f in $file_blob; do
    if [ -e "$f" ]; then
      echo "$f shouldn't exists"
      exit 1
    fi
  done
}

validate_file_nonexists '/etc/hostname'
validate_file_nonexists '/etc/resolv.conf'
validate_file_nonexists '/etc/ssh/ssh_host*'
validate_file_nonexists '/home/ec2-user/.ssh/authorized_keys'
validate_file_nonexists '/root/.ssh/authorized_keys'
validate_file_nonexists '/var/lib/cloud/data'
validate_file_nonexists '/var/lib/cloud/instance'
validate_file_nonexists '/var/lib/cloud/instances'
validate_file_nonexists '/var/lib/cloud/sem'
validate_file_nonexists '/var/lib/dhclient/*'
validate_file_nonexists '/var/lib/dhcp/dhclient.*'
validate_file_nonexists '/var/lib/dnf/history*'
validate_file_nonexists '/var/log/cloud-init-output.log'
validate_file_nonexists '/var/log/cloud-init.log'
validate_file_nonexists '/var/log/secure'
validate_file_nonexists '/var/log/wtmp'

REQUIRED_COMMANDS=(unpigz)

for ENTRY in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "$ENTRY" > /dev/null; then
    echo "Required command does not exist: '$ENTRY'"
    exit 1
  fi
done

echo "Required commands were found: ${REQUIRED_COMMANDS[*]}"

REQUIRED_FREE_MEBIBYTES=1024
TOTAL_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $2}')
FREE_MEBIBYTES=$(df -m / | tail -n1 | awk '{print $4}')
echo "Disk space in mebibytes (required/free/total): ${REQUIRED_FREE_MEBIBYTES}/${FREE_MEBIBYTES}/${TOTAL_MEBIBYTES}"
if [ ${FREE_MEBIBYTES} -lt ${REQUIRED_FREE_MEBIBYTES} ]; then
  echo "Disk space requirements not met!"
  exit 1
else
  echo "Disk space requirements were met."
fi

################################
### network ####################
################################

if sudo ip link | grep nerdctl0; then
  echo "nerdctl0 interface should be removed."
  exit 1
fi

#############################
### dkms ####################
#############################

if command -v dkms > /dev/null; then
  if ! diff <(sudo dkms status | grep 'installed') <(sudo dkms status); then
    echo "At least one dkms module is not installed."
    exit 1
  fi
fi

#############################
### nvidia drivers #####
#############################
NVIDIA_DRIVER_MODULES=(nvidia nvidia-drm nvidia-modeset nvidia-peermem nvidia-uvm)
KERNEL_RELEASE=$(uname -r)

# GRID is harvested by glob rather than from a dkms manifest, so confirm the tree
# ended up with exactly the driver's modules.
validate_nvidia_grid_modules() {
  local tree=$1
  local extra_dir="/opt/nvidia/${tree}/flavors/grid/lib/modules/${KERNEL_RELEASE}/extra"
  local module_name harvested

  for module_name in "${NVIDIA_DRIVER_MODULES[@]}"; do
    if [ ! -f "${extra_dir}/${module_name}.ko" ]; then
      echo "${extra_dir} is missing ${module_name}.ko"
      exit 1
    fi
  done

  harvested=("${extra_dir}"/*.ko)
  if [ "${#harvested[@]}" -ne "${#NVIDIA_DRIVER_MODULES[@]}" ]; then
    echo "${extra_dir} has ${#harvested[@]} modules, expected ${#NVIDIA_DRIVER_MODULES[@]}: ${harvested[*]##*/}"
    exit 1
  fi
}

NVIDIA_TREES=(lts pb)
NVIDIA_KMOD_FLAVORS=(open proprietary grid)

# A tree is pinned to one driver version so its kernel modules and userspace are compatible.
validate_nvidia_tree_version() {
  local tree=$1
  local tree_dir="/opt/nvidia/${tree}"
  local driver_version flavor extra_dir modules module_version

  driver_version=$(cat "${tree_dir}/.version")

  for flavor in "${NVIDIA_KMOD_FLAVORS[@]}"; do
    # NVIDIA publishes no aarch64 GRID runfile, so that flavor is never built there.
    if [ "${flavor}" == "grid" ] && [ "$(uname -m)" == "aarch64" ]; then
      continue
    fi

    extra_dir="${tree_dir}/flavors/${flavor}/lib/modules/${KERNEL_RELEASE}/extra"
    # The suffix varies with the kernel's module compression.
    modules=("${extra_dir}"/nvidia.ko*)
    if [ ! -e "${modules[0]}" ]; then
      echo "${extra_dir} has no nvidia.ko"
      exit 1
    fi

    module_version=$(modinfo -F version "${modules[0]}")
    if [ "${module_version}" != "${driver_version}" ]; then
      echo "${modules[0]} reports version ${module_version}, expected ${driver_version}"
      exit 1
    fi
  done

  # libcuda is version-locked to nvidia.ko
  if [ ! -e "${tree_dir}/usr/lib64/libcuda.so.${driver_version}" ]; then
    echo "${tree_dir} has no libcuda.so.${driver_version}"
    exit 1
  fi
}

# Boot-time flavor selection reads this list, so a baked tree without one picks the wrong
# kernel module.
validate_nvidia_supported_device_list() {
  local tree=$1
  local major_version

  major_version=$(cut -d. -f1 "/opt/nvidia/${tree}/.version")
  if [ ! -f "/etc/eks/nvidia-open-supported-devices-${major_version}.txt" ]; then
    echo "/etc/eks is missing the supported-devices list for major version ${major_version}"
    exit 1
  fi
}

if [[ "$ENABLE_ACCELERATOR" == "nvidia" ]]; then
  for tree in "${NVIDIA_TREES[@]}"; do
    validate_nvidia_tree_version "${tree}"
    validate_nvidia_supported_device_list "${tree}"

    # NVIDIA publishes no aarch64 GRID runfile, so that flavor is never built there.
    if [ "$(uname -m)" != "aarch64" ]; then
      validate_nvidia_grid_modules "${tree}"
    fi
  done

  # Emulated from the nvidia-persistenced rpm's %pre, which never runs on an extracted package.
  if ! getent passwd nvidia-persistenced > /dev/null; then
    echo "the nvidia-persistenced user was not created"
    exit 1
  fi

  echo "NVIDIA driver trees were validated: ${NVIDIA_TREES[*]}"
fi
