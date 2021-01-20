#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo yum update -y kernel
sudo reboot