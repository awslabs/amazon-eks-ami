#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

################################################################
# Migrate existing folder to a new partition
#
# Globals:
#   None
# Arguments:
#   1 - the path of the disk or partition
#   2 - the folder path to migration
#   3 - the mount options to use.
# Outputs:
#   None
################################################################
migrate_and_mount_disk() {
  local disk_name=$1
  local folder_path=$2
  local mount_options=$3
  local temp_path="/mnt${folder_path}"
  local old_path="${folder_path}-old"

  # install an ext4 filesystem to the disk
  mkfs -t ext4 ${disk_name}

  # check if the folder already exists
  if [ -d "${folder_path}" ]; then
    mkdir -p ${temp_path}
    mount ${disk_name} ${temp_path}
    cp -Rax ${folder_path}/* ${temp_path}
    mv ${folder_path} ${old_path}
    umount ${disk_name}
  fi

  # create the folder
  mkdir -p ${folder_path}

  # add the mount point to fstab and mount the disk
  echo "UUID=$(blkid -s UUID -o value ${disk_name}) ${folder_path} ext4 ${mount_options} 0 1" >> /etc/fstab
  mount -a

  # if selinux is enabled restore the objects on it
  if selinuxenabled; then
    restorecon -R ${folder_path}
  fi
}

################################################################
# Partition the disks based on the standard layout for common
# hardening frameworks
#
# Globals:
#   None
# Arguments:
#   1 - the name of the disk
# Outputs:
#   None
################################################################
partition_disks() {
  local disk_name=$1

  # partition the disk
  parted -a optimal -s $disk_name \
    mklabel gpt \
    mkpart var ext4 0% 20% \
    mkpart varlog ext4 20% 40% \
    mkpart varlogaudit ext4 40% 60% \
    mkpart home ext4 60% 70% \
    mkpart varlibdocker ext4 70% 90%

  # wait for the disks to settle
  sleep 5

  # migrate and mount the existing
  migrate_and_mount_disk "${disk_name}1" /var            defaults,nofail,nodev
  migrate_and_mount_disk "${disk_name}2" /var/log        defaults,nofail,nodev,nosuid
  migrate_and_mount_disk "${disk_name}3" /var/log/audit  defaults,nofail,nodev,nosuid
  migrate_and_mount_disk "${disk_name}4" /home           defaults,nofail,nodev,nosuid
  migrate_and_mount_disk "${disk_name}5" /var/lib/docker defaults,nofail
}

# upgrade the operating system
yum update -y && yum autoremove -y
yum install -y parted system-lsb-core

echo "ensure secondary disk is mounted to proper locations"
partition_disks /dev/xvdb

#
# Install additional YUM repositories, typically used for security patches.
# The format of ADDITIONAL_YUM_REPOS is: "repo=patches-repo,name=Install patches,baseurl=http://amazonlinux.$awsregion.$awsdomain/xxxx,priority=10"
# which will create the file '/etc/yum.repos.d/patches-repo.repo' having the following content:
# ```
# [patches-repo]
# name=Install patches
# baseurl=http://amazonlinux.$awsregion.$awsdomain/xxxx
# priority=10
# ```
# Note that priority is optional, but the other parameters are required. Multiple yum repos can be specified, each one separated by ';'

if [ -z "${ADDITIONAL_YUM_REPOS}" ]; then
  echo "no additional yum repo, skipping"
  exit 0
fi

AWK_CMD='
BEGIN {RS=";";FS=","}
{
  delete vars;
  for(i = 1; i <= NF; ++i) {
    n = index($i, "=");
    if(n) {
      vars[substr($i, 1, n-1)] = substr($i, n + 1)
    }
  }
  Repo = "/etc/yum.repos.d/"vars["repo"]".repo"
}
{print "["vars["repo"]"]" > Repo}
{print "name="vars["name"] > Repo}
{print "baseurl="vars["baseurl"] > Repo}
{if (length(vars["priority"]) != 0) print "priority="vars["priority"] > Repo}
'
awk "$AWK_CMD" <<< "${ADDITIONAL_YUM_REPOS}"

# upgrade the kernel
if [[ -z "$KERNEL_VERSION" ]]; then
    # Save for resetting
    OLDIFS=$IFS
    # Makes 5.4 kernel the default on 1.19 and higher
    IFS='.'
    # Convert kubernetes version in an array to compare versions
    read -ra ADDR <<< "$KUBERNETES_VERSION"
    # Reset
    IFS=$OLDIFS

    if (( ADDR[0] == 1 && ADDR[1] < 19 )); then
        KERNEL_VERSION=4.14
    else
        KERNEL_VERSION=5.4
    fi

    echo "kernel_version is unset. Setting to $KERNEL_VERSION based on kubernetes_version $KUBERNETES_VERSION"
fi

if [[ $KERNEL_VERSION == "4.14" ]]; then
    yum update -y kernel
elif [[ $KERNEL_VERSION == "5.4" ]]; then
    amazon-linux-extras install -y kernel-5.4
else
    echo "$KERNEL_VERSION is not a valid kernel version"
    exit 1
fi

reboot
