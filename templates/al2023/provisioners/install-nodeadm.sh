#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo systemctl start containerd

sudo nerdctl run \
  --rm \
  --workdir /workdir \
  --volume $PROJECT_DIR:/workdir \
  public.ecr.aws/eks-distro-build-tooling/golang:1.21 \
  make build

# move the nodeadm binary into bin folder
sudo chmod a+x $PROJECT_DIR/_bin/nodeadm
sudo mv $PROJECT_DIR/_bin/nodeadm /usr/bin/

# enable nodeadm bootstrap systemd units
sudo systemctl enable nodeadm-config nodeadm-run
