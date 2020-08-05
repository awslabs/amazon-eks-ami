#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo yum update -y kernel
sudo grubby --update-kernel=ALL --args=udev.event-timeout=300
sudo /bin/sh -c "echo 'kernel.pid_max = 999999' >> /etc/sysctl.conf"
#sudo amazon-linux-extras install kernel-ng
#sudo yum -y install kernel-4.14.133-113.112.amzn2.x86_64
#sudo grubby --set-default /boot/vmlinuz-4.14.133-113.112.amzn2.x86_64 --args="ro  console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 nvme_core.io_timeout=4294967295 rd.emergency=poweroff rd.shell=0 LANG=en_US.UTF-7 KEYTABLE=us udev.event-timeout=300"
echo "rebooting... now"
sudo reboot
