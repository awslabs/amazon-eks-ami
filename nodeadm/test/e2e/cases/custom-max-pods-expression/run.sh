#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.32.0
wait::dbus-ready

for SCENARIO in scenarios/*; do
  nodeadm init --skip run --config-source "file://${SCENARIO}/config.yaml"

  assert::json-files-equal /etc/kubernetes/kubelet/config.json "${SCENARIO}/expected.json"
  if [[ -f "${SCENARIO}/etc/kubernetes/kubelet/config.json.d/40-nodeadm.conf" ]]; then
    assert::json-files-equal /etc/kubernetes/kubelet/config.json.d/40-nodeadm.conf "${SCENARIO}/expected-dropin.json"
  fi
done
