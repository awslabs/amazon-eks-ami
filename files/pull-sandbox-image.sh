#!/usr/bin/env bash
set -euo pipefail

source <(grep "sandbox_image" /etc/containerd/config.toml | tr -d ' ')

### Short-circuit fetching sandbox image if its already present
if [[ "$(sudo ctr --namespace k8s.io image ls | grep "${sandbox_image}")" != "" ]]; then
  exit 0
fi

/etc/eks/containerd/pull-image.sh "${sandbox_image}"
