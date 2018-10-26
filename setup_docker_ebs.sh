#!/usr/bin/env bash

# Provision and mount EBS volume to /var/lib/docker
case "$FSTYPE" in
  xfs) sudo mkfs.xfs -n ftype=1 -i size=512 -L DOCKER $DOCKER_EBS_NAME ;;
  ext4) sudo mkfs.ext4 -L DOCKER $DOCKER_EBS_NAME ;;
  *) echo "FSTYPE is required!" >&2 ; exit 1 ;;
esac

sudo mkdir -vp /var/lib/docker
sudo mount $DOCKER_EBS_NAME /var/lib/docker

{
  echo -n    "$DOCKER_EBS_NAME"
  echo -n -e "\t"
  echo -n    "/var/lib/docker"
  echo -n -e "\t"
  echo -n    "$FSTYPE"
  echo -n -e "\t"
  echo -n    "defaults,nofail,nodiratime,x-systemd.before=docker.service"
  echo -n -e "\t"
  echo -n    "0"
  echo -n -e "\t"
  echo -n    "2"
  echo
} | sudo tee -a /etc/fstab
