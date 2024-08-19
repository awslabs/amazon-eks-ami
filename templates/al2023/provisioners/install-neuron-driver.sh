#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [ "$ACCELERATOR_VENDOR" != "neuron" ]; then
  exit 0
fi 

PARTITION=$(imds "/latest/meta-data/services/partition")

if [ "$PARTITION" == "aws-iso" ] || [ "$PARTITION" == "aws-iso-b" ]; then
  echo "Neuron repository not vailable in isolated regions"
  exit 0
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
metadata_expire=0" |sudo tee /etc/yum.repos.d/neuron.repo

################################################################################
### Install packages ###########################################################
################################################################################
sudo dnf --setopt=install_weak_deps=False install -y aws-neuronx-dkms