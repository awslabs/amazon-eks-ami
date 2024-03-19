#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

config_path=/tmp/aemm-default-config.json
cat /etc/aemm-default-config.json | jq '.metadata.values."instance-type" = "mock-type.large" | .dynamic.values."instance-identity-document".instanceType = "mock-type.large"' | tee ${config_path}
mock::aws ${config_path}
mock::kubelet 1.27.0
wait::dbus-ready

for config in config.*; do
  nodeadm init --skip run --config-source file://${config}
  assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config.json
done
