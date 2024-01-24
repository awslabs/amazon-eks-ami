#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::imds
wait::dbus-ready

# If clusterDNS is provided in the kubelet config, then this value should be used
# instead of the fallback DNS derived from the service IP CIDR

mock::kubelet 1.27.0
nodeadm init --skip run --config-source file://config-clusterdns-set.yaml
assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config-clusterdns-set.json

mock::kubelet 1.27.0
nodeadm init --skip run --config-source file://config-clusterdns-not-set.yaml
assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config-clusterdns-not-set.json
