#!/usr/bin/env bash

set -x
set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_ACCELERATOR" != "neuron" ]; then
  exit 0
fi

################################################################################
### Add repository #############################################################
################################################################################
sudo tee /etc/yum.repos.d/neuron.repo << 'EOF'
[neuron]
name=Neuron YUM Repository
baseurl=https://yum.repos.neuron.amazonaws.com
enabled=1
gpgcheck=1
gpgkey=https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB
metadata_expire=0

EOF

# Manually install the GPG key, verifies repository can be reached
sudo rpm --import https://yum.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB

################################################################################
########## Install Neuron container runtime      ###############################
################################################################################
sudo yum install -y aws-neuronx-dkms
sudo yum install -y aws-neuronx-oci-hook
sudo yum install -y aws-neuronx-tools
