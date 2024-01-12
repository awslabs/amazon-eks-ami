#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# use containerd to build nodeadm containerized via kaniko + nerdctl
sudo systemctl enable --now containerd
sudo nerdctl run \
  --rm \
  -v $PROJECT_DIR:/workspace \
  gcr.io/kaniko-project/executor:latest \
  --dockerfile /workspace/Dockerfile \
  --context dir:///workspace/ \
  --no-push
sudo systemctl disable containerd

# move the nodeadm binary into bin folder
sudo chmod a+x $PROJECT_DIR/_dist/bin/linux/amd64/nodeadm
sudo mv $PROJECT_DIR/_dist/bin/linux/amd64/nodeadm /usr/bin/
sudo rm -rf $PROJECT_DIR/_dist $PROJECT_DIR/_bin

# enable nodeadm bootstrap systemd units
sudo systemctl enable nodeadm-config nodeadm-run
