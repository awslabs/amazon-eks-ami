#!/bin/bash

# install containerd v2
curl -OL https://github.com/containerd/containerd/releases/download/v2.0.2/containerd-2.0.2-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-2.0.2-linux-amd64.tar.gz

SERVICE_PATH="/lib/systemd/system/containerd.service"

sudo sed -i '/^After=/ s/$/ devmapper_reload.service/' $SERVICE_PATH
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/containerd|' $SERVICE_PATH
