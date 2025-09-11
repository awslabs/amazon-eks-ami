#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.31.0

if ! nodeadm config check --config-source file://config-good.yaml; then
  echo "should have succeeded with good config:"
  cat config-good.yaml
  exit 1
fi

if nodeadm config check --config-source file://config-bad.yaml; then
  echo "should not have succeeded with bad config:"
  cat config-bad.yaml
  exit 1
fi
