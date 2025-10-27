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

if [[ "$ENABLE_ACCELERATOR" == "nvidia" ]]; then
  # Validate that for every nvidia module archived, it is one of nvidia, nvidia-open-grid, or nvidia-open,
  # and they all have the same version
  NVIDIA_DRIVER_FULL_VERSION=""
  MODULE_COUNT=0
  for ARCHIVE in /var/lib/dkms-archive/nvidia*; do
    for MODULE in "$ARCHIVE"/*; do
      CURRENT_MODULE_VERSION=$(basename "$MODULE" | sed -E 's/nvidia-(open-grid-|open-)?([0-9]+\.[0-9]+\.[0-9]+).*/\2/')
      if [[ -n "$NVIDIA_DRIVER_FULL_VERSION" ]] && [[ "$NVIDIA_DRIVER_FULL_VERSION" != "$CURRENT_MODULE_VERSION" ]]; then
        echo "Mismatch in driver versions in dkms archive: saw $NVIDIA_DRIVER_FULL_VERSION and $CURRENT_VERSION"
        ls --recursive /var/lib/dkms-archive/nvidia*
        exit 1
      else
        MODULE_COUNT=$((MODULE_COUNT + 1))
        NVIDIA_DRIVER_FULL_VERSION="$CURRENT_MODULE_VERSION"
      fi
    done
  done

  if [[ "$(uname -m)" == "x86_64" ]] && [[ "$MODULE_COUNT" != "3" ]]; then
    echo "Expected 3 nvidia modules archived, have $MODULE_COUNT"
    ls --recursive /var/lib/dkms-archive/nvidia*
    exit 1
  elif [[ "$(uname -m)" == "aarch64" ]] && [[ "$MODULE_COUNT" != "2" ]]; then
    # there are no grid drivers installed for aarch64 at the moment
    echo "Expected 2 nvidia modules archived, found $MODULE_COUNT"
    ls --recursive /var/lib/dkms-archive/nvidia*
    exit 1
  fi

  # Verify that all nvidia* packages have the same version as the nvidia driver, ensures user-space compatibility.
  # Skips nvidia-container-toolkit because it's independently versioned and released
  if rpmquery --all --queryformat '%{NAME} %{VERSION}\n' nvidia* | grep -v "$NVIDIA_DRIVER_FULL_VERSION" | grep -v "nvidia-container-toolkit"; then
    echo "Installed version mismatch for one or more nvidia package(s)!"
    exit 1
  fi
fi
