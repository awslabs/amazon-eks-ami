#!/usr/bin/env bash

function fstab_fmt() {
  local -r narg=$#
  for ((i=1 ; i < narg ; i++)); do
    echo -n "$1" ; echo -n -e "\t" ; shift
  done
  echo -n "$1"
}

# Provision and mount EBS volume to /var/lib/docker
sudo mkfs.ext4 -L DOCKER $DOCKER_EBS_NAME
sudo mkdir -vp /var/lib/docker
sudo mount $DOCKER_EBS_NAME /var/lib/docker
fstab_opts="defaults,nofail,nodiratime,x-systemd.before=docker.service"
fstab_fmt "$DOCKER_EBS_NAME" '/var/lib/docker' "ext4" "$fstab_opts" 0 2 | sudo tee -a /etc/fstab
