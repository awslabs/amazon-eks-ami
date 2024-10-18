#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo systemctl start containerd

sudo nerdctl run \
  --rm \
  --network host \
  --workdir /workdir \
  --volume $PROJECT_DIR:/workdir \
  $BUILD_IMAGE \
  make build

# cleanup build image and snapshots
sudo nerdctl rmi \
  --force \
  $BUILD_IMAGE \
  $(sudo nerdctl images -a | grep none | awk '{ print $3 }')

# move the nodeadm binary into bin folder
sudo chmod a+x $PROJECT_DIR/_bin/nodeadm
sudo mv $PROJECT_DIR/_bin/nodeadm /usr/bin/

# enable nodeadm bootstrap systemd units
sudo systemctl enable nodeadm-config nodeadm-run
