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
validate_file_nonexists '/var/lib/amazon/ssm'
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
### pause image archive ########
################################

# prevent truncated archive of /etc/eks/pause.tar
PAUSE_ARCHIVE=/etc/eks/pause.tar
if [ ! -s "${PAUSE_ARCHIVE}" ]; then
  echo "${PAUSE_ARCHIVE} is missing or empty."
  exit 1
fi

if ! tar tf "${PAUSE_ARCHIVE}" > /dev/null; then
  echo "${PAUSE_ARCHIVE} is not a complete tar archive."
  exit 1
fi

# tar tf still succeeds when archive cut between entries
# oci-layout is the last entry, so check that it exists
if ! tar tf "${PAUSE_ARCHIVE}" | grep -x "oci-layout" > /dev/null; then
  echo "${PAUSE_ARCHIVE} is truncated or not a valid tar archive."
  exit 1
fi

# truncate inside the trailing end marker bypass tar tf
# but it breaks during import
if [ $(($(stat -c %s "${PAUSE_ARCHIVE}") % 512)) -ne 0 ]; then
  echo "${PAUSE_ARCHIVE} is truncated (size is not a multiple of 512 bytes)."
  exit 1
fi
echo "Pause image archive is valid."

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
