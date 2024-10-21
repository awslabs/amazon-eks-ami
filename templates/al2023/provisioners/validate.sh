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

THROW_ERR=$SYSCTL_TEST_THROW_ERR
K_VERSION_ARR=(${KUBERNETES_VERSION//./ })
KUBERNETES_MINOR_VERSION="${K_VERSION_ARR[0]}${K_VERSION_ARR[1]}"

if [[ $AMI_NAME == *"gpu"* ]]; then
  AMI_FLAVOR="gpu"
else
  AMI_FLAVOR="standard"
fi

SYSCTL_TEST_FILE=$AMI_ALIAS

if [ -f $(pwd)/resources/$SYSCTL_TEST_FILE ]; then
  sysctl_cmd=$(eval sudo sysctl -a -e > ./sysctl_log.txt)
  while [ ! -f $(pwd)/sysctl_log.txt ]; do sleep 10; done

  sysctl_blacklist=()
  while IFS= read -r line; do
    sysctl_blacklist+=("$line")
  done < "$(pwd)/resources/sysctl_blacklist"

  diff_command="diff -b"
  for pattern in "${sysctl_blacklist[@]}"; do
    diff_command+=" -I \"$pattern\""
  done

  diff_command+=" $(pwd)/resources/$SYSCTL_TEST_FILE"
  diff_command+=" $(pwd)/sysctl_log.txt"

  if [ -f $(pwd)/sysctl_log.txt ]; then
    echo "Executing diff command: $diff_command ..."
    if ! eval $diff_command; then
      echo "Compared $AMI_NAME : $SYSCTL_TEST_FILE with $(pwd)/sysctl_log.txt"
      if $THROW_ERR ; then
        echo "Failure: Sysctl has unexpected changes. Either include the new logs in templates/shared/resources/ or undo the kernel parameter changes..."
        exit 1
      else
        echo "Warning: Sysctl has unexpected changes. Either include the new logs in templates/shared/resources/ or undo the kernel parameter changes..."
      fi
    else
      echo "Success: Sysctl has no unexpected changes!"
    fi
  else
    echo "Unhandled error: sysctl_log.txt not generated!"
    if $THROW_ERR ; then
      exit 1
    fi
  fi
else
  echo "Failure: $(pwd)/resources/$SYSCTL_TEST_FILE does not exist in the list of known AMIs."
  if $THROW_ERR ; then
    exit 1
  fi
fi

echo "Done checking sysctl log."

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
