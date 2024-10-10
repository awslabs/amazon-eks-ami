#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

sudo systemctl start containerd
cache-pause-container -i "$(nodeadm runtime ecr-uri)/eks/pause:3.5"
sudo systemctl stop containerd
