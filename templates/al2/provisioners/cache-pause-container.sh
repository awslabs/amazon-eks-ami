#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

AWS_DOMAIN=$(imds 'latest/meta-data/services/domain')
ECR_URI="$(/etc/eks/get-ecr-uri.sh ${AWS_REGION} ${AWS_DOMAIN})"

TAG="localhost/kubernetes/pause:0.1.0"
EXPORT_PATH=/etc/eks/pause.tar

sudo systemctl start containerd
cache-pause-container -i "${ECR_URI}/eks/pause:3.5" -t ${TAG} -e ${EXPORT_PATH}
sudo systemctl stop containerd

# we also need to import the image into docker, which is still default on 1.23
# and supportted below 1.25.
if vercmp ${KUBERNETES_VERSION} lt "1.25"; then
  sudo systemctl start docker
  sudo docker image import ${EXPORT_PATH} ${TAG}
  sudo systemctl stop docker
fi
