#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

#sudo yum update -y kernel
#sudo amazon-linux-extras install kernel-ng
sudo yum -y install kernel-4.14.133-113.112.amzn2.x86_64
sudo grubby --set-default /boot/vmlinuz-4.14.133-113.112.amzn2.x86_64
echo "rebooting... now"
sudo reboot
