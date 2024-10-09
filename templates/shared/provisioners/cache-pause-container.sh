#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

LOCAL_REF=${LOCAL_REF:-"localhost/kubernetes/pause:0.1.0"}
PAUSE_CONTAINER=${PAUSE_CONTAINER:-$(eval "${PAUSE_CONTAINER_CMD}")}

sudo systemctl start containerd

sudo ctr --namespace k8s.io content fetch ${PAUSE_CONTAINER} --user AWS:$(aws ecr get-login-password)
sudo ctr --namespace k8s.io image tag ${PAUSE_CONTAINER} ${LOCAL_REF}
# store the archive locally just in case so that it can be imported in the future.
sudo ctr --namespace k8s.io image export /etc/eks/pause.tar ${LOCAL_REF}
# labels the image using a CRI aware key. might not be necessary
sudo ctr --namespace=k8s.io image label ${LOCAL_REF} io.cri-containerd.pinned=pinned

sudo systemctl stop containerd
