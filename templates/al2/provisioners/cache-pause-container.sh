#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

AWS_DOMAIN=$(imds 'latest/meta-data/services/domain')
ECR_URI="$(/etc/eks/get-ecr-uri.sh ${AWS_REGION} ${AWS_DOMAIN})"

PAUSE_CONTAINER_IMAGE="${ECR_URI}/eks/pause:3.5"

sudo systemctl start containerd
cache-pause-container -i ${PAUSE_CONTAINER_IMAGE}
sudo systemctl stop containerd

# we also need to import the image into docker, which is still default on 1.23
# and supportted below 1.25.
# NOTE: there was some difficulty importing the same image exported by ctr, so
# this part follows separately
if vercmp ${KUBERNETES_VERSION} lt "1.25"; then
  sudo systemctl start docker
  aws ecr get-login-password | sudo docker login --username AWS --password-stdin ${ECR_URI}
  sudo docker pull ${PAUSE_CONTAINER_IMAGE}
  sudo docker image tag ${PAUSE_CONTAINER_IMAGE} "localhost/kubernetes/pause:0.1.0"
  sudo systemctl stop docker
fi
