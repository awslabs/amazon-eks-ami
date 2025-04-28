#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

if [[ "$CONTAINERD_VERSION" == 2.0* ]]; then
  exit 0
fi

sudo systemctl start containerd
cache-pause-container -i ${PAUSE_CONTAINER_IMAGE}
sudo systemctl stop containerd
