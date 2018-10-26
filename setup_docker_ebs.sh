#!/usr/bin/env bash

# Provision and mount EBS volume to /var/lib/docker
sudo mkfs -t xfs -n ftype=1 -L DOCKER $DOCKER_EBS_NAME
sudo mkdir -vp /var/lib/docker
sudo mount $DOCKER_EBS_NAME /var/lib/docker
sudo bash -c "echo -e '$DOCKER_EBS_NAME\t/var/lib/docker\txfs\tdefaults,nofail,x-systemd.before=docker.service\t0\t2' >> /etc/fstab"
