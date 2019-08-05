#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'

TEMPLATE_DIR=${TEMPLATE_DIR:-/tmp/worker}

################################################################################
### Packages ###################################################################
################################################################################

# Update the OS to begin with to catch up to the latest packages.
sudo yum update -y

# Install necessary packages
sudo yum install -y \
    aws-cfn-bootstrap \
    awscli \
    chrony \
    conntrack \
    curl \
    jq \
    ec2-instance-connect \
    nfs-utils \
    socat \
    unzip \
    ntp \
    wget \
    git

sudo systemctl enable ntpd

################################################################################
### iptables ###################################################################
################################################################################

# Enable forwarding via iptables
sudo iptables -P FORWARD ACCEPT
sudo bash -c "/sbin/iptables-save > /etc/sysconfig/iptables"

sudo mv $TEMPLATE_DIR/iptables-restore.service /etc/systemd/system/iptables-restore.service

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore


sudo systemctl reboot

