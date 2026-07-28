#!/usr/bin/env bash

sudo rm -f /etc/update-motd.d/70-available-updates

# Clean up dnf caches to reduce the image size
sudo dnf clean all
sudo rm -rf /var/cache/dnf

# Clean up files to reduce confusion during debug
sudo rm -rf \
  /etc/hostname \
  /etc/machine-id \
  /etc/resolv.conf \
  /etc/ssh/ssh_host* \
  /home/ec2-user/.ssh/authorized_keys \
  /root/.ssh/authorized_keys \
  /var/lib/cloud/data \
  /var/lib/cloud/instance \
  /var/lib/cloud/instances \
  /var/lib/cloud/sem \
  /var/lib/dhclient/* \
  /var/lib/dhcp/dhclient.* \
  /var/lib/yum/history \
  /var/lib/dnf/history* \
  /var/log/cloud-init-output.log \
  /var/log/cloud-init.log \
  /var/log/secure \
  /var/log/wtmp \
  /var/log/messages

# Stop auditd before purging: a blind rm against a running auditd leaves the held
# inode in place, so build-time AVC denials ship in the AMI.
sudo service auditd stop 2> /dev/null || true
sudo truncate -s0 /var/log/audit/audit.log 2> /dev/null || true
sudo rm -f /var/log/audit/audit.log.* 2> /dev/null || true
sudo service auditd start 2> /dev/null || true

sudo touch /etc/machine-id
