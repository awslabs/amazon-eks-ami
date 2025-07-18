#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ "$HARDENED_IMAGE" == "true" ]]; then
  sudo chcon -t bin_t /usr/bin/nodeadm && \
  sudo systemctl disable firewalld && \
  sudo yum install make bzip2 selinux-policy-devel -y && \
  curl -L https://github.com/KrisJohnstone/container-selinux/archive/refs/heads/go-1.24.zip -o /tmp/container-selinux.zip && \
  cd /tmp/ && \
  unzip container-selinux.zip && \
  cd /tmp/container-selinux-go-1.24/ && \
  sed -i '/user_namespace/d' container.te && \
  sudo make install && \
  sudo yum remove make bzip2 -y && \
  # There are policies provided by aws that dont appear to be upstream.
  sudo yum install container-selinux -y
fi
