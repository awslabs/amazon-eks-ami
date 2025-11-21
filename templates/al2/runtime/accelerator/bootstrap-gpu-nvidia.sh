#!/usr/bin/env bash

set -o errexit
set -o nounset

if ! gpu-ami-util has-nvidia-devices; then
  echo >&2 "no NVIDIA devices are present, nothing to do!"
  exit 0
fi

CONTAINER_RUNTIME="containerd"
# add 'nvidia' runtime to container runtime config, and set it as the default
# otherwise, all Pods need to speciy the runtimeClassName
nvidia-ctk runtime configure --runtime=$CONTAINER_RUNTIME --set-as-default
# restart container runtime to pick up the changes
systemctl restart $CONTAINER_RUNTIME
