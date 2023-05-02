#!/usr/bin/env bash
#
# Do basic validation of the generated AMI

# Validates that a file or blob doesn't exist
#
# Arguments:
#   a file name or blob
# Returns:
#   1 if a file exists, after printing an error
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
validate_file_nonexists '/var/lib/yum/history'
validate_file_nonexists '/var/log/cloud-init-output.log'
validate_file_nonexists '/var/log/cloud-init.log'
validate_file_nonexists '/var/log/secure'
validate_file_nonexists '/var/log/wtmp'

actual_kernel=$(uname -r)
echo "Verifying that kernel version $actual_kernel matches $KERNEL_VERSION..."

if [[ $actual_kernel == $KERNEL_VERSION* ]]; then
  echo "Kernel matches expected version!"
else
  echo "Kernel does not match expected version!"
  exit 1
fi

echo "Verifying that the package versionlocks are correct..."

function versionlock-entries() {
  # the format of this output is EPOCH:NAME-VERSION-RELEASE.ARCH
  # more info in yum-versionlock(1)
  # rpm doesn't accept EPOCH when querying the db, so remove it
  yum versionlock list --quiet | cut -d ':' -f2
}

function versionlock-packages() {
  versionlock-entries | xargs -I '{}' rpm --query '{}' --queryformat '%{NAME}\n'
}

for ENTRY in $(versionlock-entries); do
  if ! rpm --query "$ENTRY" &> /dev/null; then
    echo "There is no package matching the versionlock entry: '$ENTRY'"
    exit 1
  fi
done

LOCKED_PACKAGES=$(versionlock-packages | wc -l)
UNIQUE_LOCKED_PACKAGES=$(versionlock-packages | sort -u | wc -l)
if [ $LOCKED_PACKAGES -ne $UNIQUE_LOCKED_PACKAGES ]; then
  echo "Package(s) have multiple version locks!"
  versionlock-entries
fi

echo "Package versionlocks are correct!"

REQUIRED_COMMANDS=(unpigz)

for ENTRY in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "$ENTRY" > /dev/null; then
    echo "Required command does not exist: '$ENTRY'"
    exit 1
  fi
done

echo "Required commands were found: ${REQUIRED_COMMANDS[*]}"
