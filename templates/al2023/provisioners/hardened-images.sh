#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ "$HARDENED_IMAGE" == "true" ]]; then
  sudo chcon -t bin_t /usr/bin/nodeadm
  sudo chcon -t bin_t /usr/bin/kubelet
  sudo systemctl disable firewalld
fi
