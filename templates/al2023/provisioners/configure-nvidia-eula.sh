#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ACCELERATOR_VENDOR" != "nvidia" ]; then
  exit 0
fi 
echo "Configuring NVIDIA End User License Agreement..."

echo '#!/bin/sh

echo -n "
#############################################################
By using the EKS GPU Optimized AMI, you agree to the NVIDIA Cloud End User License Agreement
https://s3.amazonaws.com/EULA/NVidiaEULAforAWS.pdf.
#############################################################
"'| sudo tee /etc/eks/nvidia-eula

sudo chmod +x /etc/eks/nvidia-eula

echo "[Unit]
Description=Display NVIDIA driver EULA

[Service]
Type=oneshot
ExecStart=/etc/eks/nvidia-eula

[Install]
WantedBy=basic.target
"| sudo tee /etc/systemd/system/nvidia-eula.service

sudo chmod +x /etc/systemd/system/nvidia-eula.service

sudo systemctl daemon-reload
sudo systemctl enable nvidia-eula
