#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "neuron" ]; then
  exit 0
fi

PARTITION=$(imds "/latest/meta-data/services/partition")

if [[ "$PARTITION" =~ ^aws-iso(-[bef])?$ ]]; then
  echo "Neuron repository not vailable in isolated regions"
  exit 1
fi

################################################################################
### Add repository #############################################################
################################################################################
echo "[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
gpgcheck=1
gpgkey=https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB
metadata_expire=0" | sudo tee /etc/yum.repos.d/neuron.repo

################################################################################
### Install packages ###########################################################
################################################################################

sudo dnf -y install \
  kernel-devel-$(uname -r) \
  kernel-headers-$(uname -r)

sudo dnf install -y aws-neuronx-dkms aws-neuronx-tools
