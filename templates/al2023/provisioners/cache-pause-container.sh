#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

sudo systemctl start containerd
cache-pause-container -i ${PAUSE_CONTAINER_IMAGE}
sudo systemctl stop containerd
