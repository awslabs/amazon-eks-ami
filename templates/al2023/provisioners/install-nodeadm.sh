#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo systemctl start containerd

# if the image is from an ecr repository then try authenticate first
if [[ "$BUILD_IMAGE" == *"dkr.ecr"* ]]; then
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${BUILD_IMAGE%%/*}"
fi

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
