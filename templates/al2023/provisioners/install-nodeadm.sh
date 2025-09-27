#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# Check required variables
if [ -z "$BUILD_IMAGE" ]; then
  echo "Error: BUILD_IMAGE is required"
  exit 1
fi

if [ -z "$AWS_REGION" ]; then
  echo "Error: AWS_REGION is required"
  exit 1
fi

if [ -z "$PROJECT_DIR" ]; then
  echo "Error: PROJECT_DIR is required"
  exit 1
fi

sudo systemctl start containerd

# if the image is from an ecr repository then try authenticate first
if [[ "$BUILD_IMAGE" == *"dkr.ecr"* ]]; then
  # nerdctl needs the https:// prefix when logging in to the repository
  # see: https://github.com/containerd/nerdctl/issues/742
  aws ecr get-login-password --region $AWS_REGION | sudo nerdctl login --username AWS --password-stdin "https://${BUILD_IMAGE%%/*}"
fi

sudo nerdctl run \
  --rm \
  --network none \
  --workdir /workdir \
  --volume $PROJECT_DIR:/workdir \
  --env GOTOOLCHAIN=local \
  $BUILD_IMAGE \
  make build

# cleanup build image and snapshots
sudo nerdctl rmi \
  --force \
  $BUILD_IMAGE

# cleanup dangling images
sudo nerdctl image prune --force

# move the nodeadm binaries into bin folder
sudo chmod a+x $PROJECT_DIR/_bin/*
sudo mv --context \
  $PROJECT_DIR/_bin/nodeadm \
  $PROJECT_DIR/_bin/nodeadm-internal \
  /usr/bin/

# enable nodeadm bootstrap systemd units
sudo systemctl enable \
  nodeadm-boot-hook \
  nodeadm-config \
  nodeadm-run
