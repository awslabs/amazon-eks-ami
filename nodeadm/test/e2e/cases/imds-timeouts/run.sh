#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

wait::dbus-ready
mock::kubelet 1.29.0

# configure without launching the imds mock service
ENABLE_IMDS_MOCK=false mock::aws

if nodeadm init --skip run; then
  echo "bootstrap should not succeed when EC2 IMDS APIs are not reachable."
  exit 1
fi

# start the imds mock part way into the initialization to mimic
# delayed availability of IMDS
{ sleep 10 && ENABLE_AWS_MOCK=false mock::aws; } &
nodeadm init --skip run
