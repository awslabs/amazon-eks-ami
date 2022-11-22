#!/usr/bin/env bash
set -euo pipefail

sandbox_image="$(awk -F'[ ="]+' '$1 == "sandbox_image" { print $2 }' /etc/containerd/config.toml)"

### Short-circuit fetching sandbox image if its already present
if [[ "$(sudo ctr --namespace k8s.io image ls | grep $sandbox_image)" != "" ]]; then
  exit 0
fi

/etc/eks/containerd/pull-image.sh "${sandbox_image}"
