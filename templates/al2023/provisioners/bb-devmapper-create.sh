#!/bin/bash
set -ex

sudo dnf install -y git make

# Block device to use for devmapper thin-pool
BLOCK_DEV=/dev/sdf
POOL_NAME=devpool
VG_NAME=containerd

# Install container-storage-setup tool
git clone https://github.com/projectatomic/container-storage-setup.git
cd container-storage-setup/
sudo make install-core
echo "Using version $(container-storage-setup -v)"

cd ../
rm -rf container-storage-setup

# Create configuration file
# Refer to `man container-storage-setup` to see available options
sudo tee /etc/sysconfig/containerd-storage-setup << EOF
DEVS=${BLOCK_DEV}
VG=${VG_NAME}
CONTAINER_THINPOOL=${POOL_NAME}
EOF

# Run the script
sudo container-storage-setup

sudo tee /usr/lib/systemd/system/containerd-storage-setup.service << EOF
[Unit]
Description=Containerd Storage Setup
After=cloud-init.service
Before=containerd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/container-storage-setup
EnvironmentFile=-/etc/sysconfig/containerd-storage-setup

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable /usr/lib/systemd/system/containerd-storage-setup.service
