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

echo "Verifying that the kernel has the correct versionlock..."

# only one version of the kernel should be version locked
if [ $(yum versionlock list --quiet | grep -c "kernel") -ne 1 ]; then
  echo "More than one version of the kernel has a versionlock!"
  yum versionlock list
  exit 1
fi

# the current version of the kernel should be version locked
if [ $(yum versionlock list --quiet | grep -c "kernel-$KERNEL_VERSION") -ne 1 ]; then
  echo "The current version of the kernel does not have a versionlock!"
  yum versionlock list
  exit 1
fi

echo "Kernel has the correct versionlock!"
