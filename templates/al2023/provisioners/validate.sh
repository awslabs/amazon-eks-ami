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

# igzip is only installed on x86_64, where it outperforms unpigz.
if [ "$(uname -m)" == "x86_64" ]; then
  REQUIRED_COMMANDS+=(igzip)
fi

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
NVIDIA_DRIVER_MODULES=(nvidia nvidia-drm nvidia-modeset nvidia-uvm)
KERNEL_RELEASE=$(uname -r)

validate_nvidia_boot_modules() {
  local tree=$1
  local flavor=$2
  local extra_dir="/opt/nvidia/${tree}/flavors/${flavor}/lib/modules/${KERNEL_RELEASE}/extra"
  local expected=("${NVIDIA_DRIVER_MODULES[@]}")
  local module_name

  # gdrdrv is only harvested on the open flavor, and only when the build enabled it.
  if [ "${flavor}" = "open" ] && [ "${ENABLE_NVIDIA_GDRCOPY_DRIVER}" = "true" ]; then
    expected+=(gdrdrv)
  fi

  for module_name in "${expected[@]}"; do
    # The suffix varies with the kernel's module compression.
    if ! compgen -G "${extra_dir}/${module_name}.ko*" > /dev/null; then
      echo "${extra_dir} is missing ${module_name}.ko"
      exit 1
    fi
  done
}

# vGPU license userspace the rpm tree has no package for, so it can only come from the GRID runfile.
# Node paths, since a tree mirrors /.
NVIDIA_GRID_USERSPACE=(
  /usr/bin/nvidia-gridd
  /usr/lib/systemd/system/nvidia-gridd.service
  /etc/nvidia/gridd.conf.template
)

validate_nvidia_grid_userspace() {
  local tree=$1
  local path

  for path in "${NVIDIA_GRID_USERSPACE[@]}"; do
    if [ ! -f "/opt/nvidia/${tree}/${path}" ]; then
      echo "tree ${tree} is missing ${path}"
      exit 1
    fi
  done
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

# The fabricmanager condition decides from lspci alone, so it can be exercised against canned
# lspci output. Any exit from 1-254 makes systemd skip the unit, which is why a broken condition
# must fail the build rather than ship: it would silently skip Fabric Manager on NVSwitch hosts.
validate_nvidia_fabricmanager_condition() {
  local condition=/etc/eks/nvidia-fabricmanager-condition.sh
  local dropin=/etc/systemd/system/nvidia-fabricmanager.service.d/10-condition.conf

  if [ ! -x "${condition}" ]; then
    echo "${condition} is missing or not executable"
    exit 1
  fi
  if ! grep -q "^ExecCondition=${condition}$" "${dropin}"; then
    echo "${dropin} does not gate nvidia-fabricmanager.service on ${condition}"
    exit 1
  fi

  local fake
  fake=$(mktemp -d)
  # fake lspci: the listing comes from $fake/devices, per-device details from $fake/<bdf>.
  # an absent file makes that call fail, like lspci would.
  cat > "${fake}/lspci" << 'EOF'
#!/usr/bin/env bash
dir=$(dirname "$0")
if [[ "$*" == *-mm* ]]; then
  cat "${dir}/devices" 2> /dev/null || exit 1
else
  while [[ "$1" != "-s" ]]; do shift; done
  cat "${dir}/$2" 2> /dev/null || exit 1
fi
EOF
  chmod 0755 "${fake}/lspci"

  # `lspci -D -n -mm` lines. Fields: domain:bus:slot.fn "class" "vendor" "device" [-rREV]
  # "subvendor" "subdevice". Vendor, class and device IDs match /usr/share/hwdata/pci.ids,
  # except the Blackwell GPUs (2901, 2941), which are newer than it and come from the
  # nvidia-open-supported-devices-*.txt lists.
  # captured verbatim from a g4dn.xlarge: 1eb8 = TU104GL [Tesla T4]
  local t4='0000:00:1e.0 "0302" "10de" "1eb8" -ra1 "10de" "12a2"'
  # captured verbatim from a p4d.24xlarge: 20b0 = GA100 [A100 SXM4 40GB]
  local a100='0000:10:1c.0 "0302" "10de" "20b0" -ra1 "10de" "134f"'
  # captured verbatim from a p4d.24xlarge: 1af1 = GA100 [A100 NVSwitch], class 0680
  local nvswitch='0000:80:1a.0 "0680" "10de" "1af1" -ra1 "10de" "13b8"'
  # hand-written, not captured: 2901 = B200, 2941 = GB200 (on a non-zero PCI domain, 0008, so the
  # domain prefix gets exercised), 1021 = MT2910 Family [ConnectX-7] with class 0207 (Infiniband
  # controller)
  local b200='0000:51:00.0 "0302" "10de" "2901" -ra1 "10de" "1999"'
  local gb200='0008:06:00.0 "0302" "10de" "2941" -ra1 "10de" "2046"'
  local cx7='0000:73:00.0 "0207" "15b3" "1021" "15b3" "0087"'

  # name|expected exit|lspci listing (empty = lspci fails)|cx7 details (empty = lspci -s fails)
  local cases=(
    "single-gpu, no fabric|1|${t4}|"
    "hgx a100, nvswitches on pci|0|${a100}"$'\n'"${nvswitch}|"
    "hgx b200, sw_mng bridge|0|${b200}"$'\n'"${cx7}|Capabilities: [48] Vital Product Data\n    [V2] Vendor specific: SW_MNG"
    "hgx b200, bridge unreadable|0|${b200}"$'\n'"${cx7}|"
    "cx7 without sw_mng|1|${t4}"$'\n'"${cx7}|Capabilities: [48] Vital Product Data"
    "gb200, fabric off-host|1|${gb200}"$'\n'"${cx7}|    [V2] Vendor specific: SW_MNG"
    "lspci fails|0||"
  )

  local case name expected devices details actual
  for case in "${cases[@]}"; do
    IFS='|' read -r name expected devices details <<< "${case//$'\n'/\\n}"
    rm -f "${fake}/devices" "${fake}/0000:73:00.0"
    [ -n "${devices}" ] && printf '%b\n' "${devices}" > "${fake}/devices"
    [ -n "${details}" ] && printf '%b\n' "${details}" > "${fake}/0000:73:00.0"
    actual=0
    PATH="${fake}:${PATH}" "${condition}" > /dev/null || actual=$?
    if [ "${actual}" != "${expected}" ]; then
      echo "${condition}: case '${name}' exited ${actual}, expected ${expected}"
      exit 1
    fi
  done
  rm -rf "${fake}"
}

if [[ "$ENABLE_ACCELERATOR" == "nvidia" ]]; then
  for tree in "${NVIDIA_TREES[@]}"; do
    validate_nvidia_tree_version "${tree}"
    validate_nvidia_supported_device_list "${tree}"
    validate_nvidia_boot_modules "${tree}" open
    validate_nvidia_boot_modules "${tree}" proprietary

    # NVIDIA publishes no aarch64 GRID runfile, so that flavor is never built there.
    if [ "$(uname -m)" != "aarch64" ]; then
      validate_nvidia_boot_modules "${tree}" grid
      validate_nvidia_grid_userspace "${tree}"
    fi
  done

  # Emulated from the nvidia-persistenced rpm's %pre, which never runs on an extracted package.
  if ! getent passwd nvidia-persistenced > /dev/null; then
    echo "the nvidia-persistenced user was not created"
    exit 1
  fi

  #############################
  ### boot-time integration ###
  #############################

  # Every baked tree must carry its identity marker.
  for tree in "${NVIDIA_TREES[@]}"; do
    if [ ! -f "/opt/nvidia/${tree}/.tree-${tree}" ]; then
      echo "/opt/nvidia/${tree}/.tree-${tree} is missing"
      exit 1
    fi
  done

  # Every baked tree must carry the daemon services setup will install at first boot.
  for tree in "${NVIDIA_TREES[@]}"; do
    for DAEMON in nvidia-persistenced nvidia-fabricmanager; do
      if [ ! -f "/opt/nvidia/${tree}/usr/lib/systemd/system/${DAEMON}.service" ]; then
        echo "tree ${tree} is missing ${DAEMON}.service"
        exit 1
      fi
    done
  done

  # nvidia-setup.service must Before= the daemon services so systemd orders them
  # correctly on subsequent boots
  for DAEMON in nvidia-persistenced.service nvidia-fabricmanager.service nvidia-gridd.service; do
    if ! grep -q "^Before=.*\b${DAEMON}\b" /etc/systemd/system/nvidia-setup.service; then
      echo "nvidia-setup.service does not declare Before=${DAEMON}"
      exit 1
    fi
  done

  validate_nvidia_fabricmanager_condition

  if [ ! -f "/etc/systemd/system/set-nvidia-clocks.service" ]; then
    echo "set-nvidia-clocks.service was not staged at build time"
    exit 1
  fi
  # set-nvidia-clocks should not be pulled into the boot-ordering chain b/c it has an ordering
  # dependency with nvidia-persistenced, which is not added until first boot
  if compgen -G "/etc/systemd/system/*.wants/set-nvidia-clocks.service" > /dev/null \
    || compgen -G "/etc/systemd/system/*.requires/set-nvidia-clocks.service" > /dev/null; then
    echo "set-nvidia-clocks.service has activation links at build time; must be enabled by setup at first boot"
    exit 1
  fi

  # these daemons are expected to be added at runtime, not build-time, since the .service files are extracted from
  # version-specific RPMs into the tree
  for DAEMON in nvidia-persistenced nvidia-fabricmanager nvidia-gridd; do
    if [ -f "/usr/lib/systemd/system/${DAEMON}.service" ]; then
      echo "/usr/lib/systemd/system/${DAEMON}.service exists at build time; should be installed by setup at first boot"
      exit 1
    fi
  done

  if ! [[ $(imds /latest/meta-data/services/partition) =~ ^aws-iso ]]; then
    # ISO partitions use the AL NVIDIA repo, which does not include module streams
    if ! grep -q 'stream=DRIVER_TREE_VERSION_PLACEHOLDER' /etc/dnf/modules.d/nvidia-driver.module; then
      echo "/etc/dnf/modules.d/nvidia-driver.module missing placeholder for driver version"
      exit 1
    fi
  fi

  echo "NVIDIA driver trees were validated: ${NVIDIA_TREES[*]}"
fi
