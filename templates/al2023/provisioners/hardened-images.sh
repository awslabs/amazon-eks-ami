#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ "$HARDENED_IMAGE" == "true" ]]; then
  sudo chcon -t bin_t /usr/bin/nodeadm
  sudo systemctl disable firewalld
  sudo yum install container-selinux -y
fi
